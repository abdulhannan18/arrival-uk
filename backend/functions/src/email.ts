import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { createHmac, timingSafeEqual } from "crypto";
import { escapeHtml, sanitizeHTTPSURL } from "./utils/sanitization";
import { isPrivilegedCaller } from "./utils/privileged";
import { enforceRateLimit } from "./utils/rateLimit";
import { assertCallableAppCheck } from "./utils/appCheck";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const CUSTOM_EMAIL_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const CUSTOM_EMAIL_RATE_LIMIT_MAX = 20;
const MAX_TEMPLATE_VARIABLES = 20;
const MAX_TEMPLATE_VARIABLE_KEY_LENGTH = 64;
const MAX_TEMPLATE_VARIABLE_VALUE_LENGTH = 500;
const MAX_UNSUBSCRIBE_LINK_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const SENDGRID_API_KEY_SECRET = "SENDGRID_API_KEY";
const UNSUBSCRIBE_HMAC_SECRET = "UNSUBSCRIBE_HMAC_SECRET";
const ALLOWED_CUSTOM_EMAIL_TEMPLATES = new Set([
  "support_followup",
  "broadcast_update",
  "maintenance_notice",
]);
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const FIREBASE_UID_PATTERN = /^[A-Za-z0-9:_-]{6,128}$/;
let didWarnInvalidFromEmail = false;
let didWarnInvalidAppURL = false;
let didWarnMissingUnsubscribeSecret = false;
const emailRuntime = functions.runWith({
  secrets: [SENDGRID_API_KEY_SECRET, UNSUBSCRIBE_HMAC_SECRET],
});

type MailPayload = {
  to: string;
  from: string;
  subject: string;
  html: string;
  headers?: Record<string, string>;
};

type SendGridClient = {
  setApiKey: (key: string) => void;
  send: (mail: MailPayload) => Promise<unknown>;
};

let cachedSendGridClient: SendGridClient | null | undefined;

function getSendGridClient(): SendGridClient | null {
  if (cachedSendGridClient !== undefined) {
    return cachedSendGridClient;
  }

  try {
    // Optional runtime dependency. Keeps scaffold compile-safe before credentials/deps are installed.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const mailer = require("@sendgrid/mail") as SendGridClient;
    const apiKey = process.env.SENDGRID_API_KEY;
    if (!apiKey) {
      cachedSendGridClient = null;
      return cachedSendGridClient;
    }
    mailer.setApiKey(apiKey);
    cachedSendGridClient = mailer;
    return cachedSendGridClient;
  } catch {
    cachedSendGridClient = null;
    return cachedSendGridClient;
  }
}

function fromEmail(): string {
  const configured = process.env.SENDGRID_FROM_EMAIL ?? "noreply@arrivaluk.app";

  if (EMAIL_PATTERN.test(configured)) {
    return configured;
  }

  if (!didWarnInvalidFromEmail) {
    didWarnInvalidFromEmail = true;
    functions.logger.warn("Invalid SENDGRID_FROM_EMAIL. Falling back to noreply@arrivaluk.app");
  }

  return "noreply@arrivaluk.app";
}

function appName(): string {
  return ((process.env.APP_NAME ||
    functions.config()?.app?.name) as string | undefined) ?? "Arrival UK";
}

function appURL(): string {
  const fallback = "https://arrivaluk.app";
  const configured = ((process.env.APP_URL ||
    functions.config()?.app?.url) as string | undefined) ?? fallback;
  const sanitized = sanitizeHTTPSURL(configured, fallback);

  if (!didWarnInvalidAppURL && sanitized == fallback && configured != fallback) {
    didWarnInvalidAppURL = true;
    functions.logger.warn("Invalid APP_URL. Falling back to https://arrivaluk.app");
  }

  return sanitized;
}

function sanitizeURL(raw: string): string {
  return sanitizeHTTPSURL(raw, appURL());
}

function unsubscribeSecret(): string | null {
  const configured = process.env.UNSUBSCRIBE_HMAC_SECRET;
  const normalized = configured?.trim() ?? "";
  if (normalized.length > 0) {
    return normalized;
  }

  if (!didWarnMissingUnsubscribeSecret) {
    didWarnMissingUnsubscribeSecret = true;
    functions.logger.warn(
      "Missing unsubscribe secret; weekly digest links will fall back to in-app preferences only"
    );
  }
  return null;
}

function unsubscribeBaseURL(): string {
  const fallbackProjectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
  const fallback = fallbackProjectId
    ? `https://us-central1-${fallbackProjectId}.cloudfunctions.net/unsubscribeWeeklyDigest`
    : `${appURL()}/unsubscribe-weekly`;

  const configured = (
    process.env.WEEKLY_DIGEST_UNSUBSCRIBE_URL ||
    functions.config()?.app?.weekly_digest_unsubscribe_url
  ) as string | undefined;

  return sanitizeHTTPSURL(configured ?? fallback, fallback);
}

function base64Url(buffer: Buffer): string {
  return buffer.toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function signUnsubscribePayload(secret: string, userId: string, issuedAtMs: number): string {
  const digest = createHmac("sha256", secret)
    .update(`${userId}.${issuedAtMs}`)
    .digest();
  return base64Url(digest);
}

function safeCompare(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return timingSafeEqual(leftBuffer, rightBuffer);
}

function buildWeeklyDigestUnsubscribeURL(userId: string, nowMs = Date.now()): string | null {
  const secret = unsubscribeSecret();
  if (!secret) return null;
  if (!FIREBASE_UID_PATTERN.test(userId)) return null;

  const issuedAtMs = Math.floor(nowMs);
  const signature = signUnsubscribePayload(secret, userId, issuedAtMs);
  const url = new URL(unsubscribeBaseURL());
  url.searchParams.set("uid", userId);
  url.searchParams.set("ts", String(issuedAtMs));
  url.searchParams.set("sig", signature);
  return url.toString();
}

function isValidUnsubscribeRequest(
  userId: string,
  issuedAtRaw: string,
  signature: string,
  nowMs = Date.now(),
  secret = unsubscribeSecret()
): boolean {
  if (!secret) return false;
  if (!FIREBASE_UID_PATTERN.test(userId)) return false;
  if (!signature || signature.length < 24 || signature.length > 128) return false;

  const issuedAtMs = Number(issuedAtRaw);
  if (!Number.isFinite(issuedAtMs) || issuedAtMs <= 0) return false;

  const ageMs = nowMs - issuedAtMs;
  if (ageMs < 0 || ageMs > MAX_UNSUBSCRIBE_LINK_AGE_MS) return false;

  const expectedSignature = signUnsubscribePayload(secret, userId, issuedAtMs);
  return safeCompare(signature, expectedSignature);
}

function extractEmailDomain(email: string): string | null {
  const atIndex = email.lastIndexOf("@");
  if (atIndex < 0 || atIndex + 1 >= email.length) return null;
  return email.slice(atIndex + 1).toLowerCase();
}

function welcomeHTML(displayName: string): string {
  const safeDisplayName = escapeHtml(displayName);
  const safeAppName = escapeHtml(appName());
  const safeAppURL = sanitizeURL(appURL());
  return `
  <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
    <h2>Welcome to ${safeAppName}</h2>
    <p>Hi ${safeDisplayName},</p>
    <p>Thanks for joining. We’ll help you plan your UK arrival step by step.</p>
    <p><a href="${safeAppURL}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Open ${safeAppName}</a></p>
  </div>
  `.trim();
}

function supportCreatedHTML(displayName: string, ticketId: string, subject: string): string {
  const safeDisplayName = escapeHtml(displayName);
  const safeTicketId = escapeHtml(ticketId);
  const safeSubject = escapeHtml(subject);
  return `
  <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
    <h2>Support Ticket Created</h2>
    <p>Hi ${safeDisplayName},</p>
    <p>We received your request and will reply soon.</p>
    <p><b>Ticket:</b> #${safeTicketId}<br/><b>Subject:</b> ${safeSubject}</p>
  </div>
  `.trim();
}

async function sendMail(payload: MailPayload): Promise<void> {
  const client = getSendGridClient();
  if (!client) {
    functions.logger.warn("SendGrid not configured; email skipped", {
      toDomain: extractEmailDomain(payload.to),
      subject: payload.subject,
    });
    return;
  }

  await client.send(payload);
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function parseTemplateVariables(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  const raw = value as Record<string, unknown>;
  const output: Record<string, string> = {};
  let acceptedCount = 0;
  for (const [key, current] of Object.entries(raw)) {
    if (acceptedCount >= MAX_TEMPLATE_VARIABLES) break;
    if (typeof current !== "string") continue;
    const normalizedKey = key.trim().slice(0, MAX_TEMPLATE_VARIABLE_KEY_LENGTH);
    if (!normalizedKey) continue;
    output[normalizedKey] = current.trim().slice(0, MAX_TEMPLATE_VARIABLE_VALUE_LENGTH);
    acceptedCount += 1;
  }
  return output;
}

type CustomEmailAuditStatus = "attempted" | "sent" | "failed";

async function writeCustomEmailAudit(
  userId: string,
  templateKey: string,
  to: string,
  status: CustomEmailAuditStatus,
  errorCode?: string
): Promise<void> {
  const safeTemplateKey = templateKey.trim().toLowerCase().slice(0, 120);
  const domain = extractEmailDomain(to);

  await db.collection("ops").doc("emailAudit").collection("items").add({
    userId,
    templateKey: safeTemplateKey,
    recipientDomain: domain,
    status,
    errorCode: errorCode ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function renderCustomTemplate(
  templateKey: string,
  variables: Record<string, string>
): { subject: string; html: string } {
  const recipientName = escapeHtml(variables.recipientName || "there");
  const ctaURL = sanitizeURL(variables.ctaURL || appURL());
  const message = escapeHtml(variables.message || "We have an update for you.");
  const appLabel = escapeHtml(appName());

  if (templateKey === "support_followup") {
    return {
      subject: `${appLabel} support follow-up`,
      html: `
      <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
        <h2>Support Follow-up</h2>
        <p>Hi ${recipientName},</p>
        <p>${message}</p>
      </div>
      `.trim(),
    };
  }

  if (templateKey === "maintenance_notice") {
    return {
      subject: `${appLabel} scheduled maintenance`,
      html: `
      <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
        <h2>Scheduled Maintenance</h2>
        <p>Hi ${recipientName},</p>
        <p>${message}</p>
        <p>We appreciate your patience.</p>
      </div>
      `.trim(),
    };
  }

  return {
    subject: `${appLabel} update`,
    html: `
    <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
      <h2>Update from ${appLabel}</h2>
      <p>Hi ${recipientName},</p>
      <p>${message}</p>
      <p><a href="${ctaURL}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Open ${appLabel}</a></p>
    </div>
    `.trim(),
  };
}

export const sendWelcomeEmailOnSignup = emailRuntime.auth.user().onCreate(async (user) => {
  if (!user.email) return;

  try {
    await sendMail({
      to: user.email,
      from: fromEmail(),
      subject: `Welcome to ${appName()}`,
      html: welcomeHTML(user.displayName ?? "there"),
    });
  } catch (error) {
    functions.logger.error("Failed to send welcome email", {
      userId: user.uid,
      toDomain: extractEmailDomain(user.email),
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});

export const sendWeeklyDigestEmail = emailRuntime.pubsub
  .schedule("every monday 09:00")
  .timeZone("Europe/London")
  .onRun(async () => {
    const maxConcurrentSends = 12;
    const pageSize = 300;
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    let totalRecipients = 0;
    const pendingSends: Promise<void>[] = [];
    const flushPending = async (): Promise<void> => {
      if (pendingSends.length === 0) return;
      const activeBatch = pendingSends.splice(0, pendingSends.length);
      await Promise.allSettled(activeBatch);
    };

    while (true) {
      let usersQuery = db
        .collection("users")
        .where("preferences.notifications.weeklyDigest", "==", true)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(pageSize);

      if (lastDoc) {
        usersQuery = usersQuery.startAfter(lastDoc);
      }

      const usersPage = await usersQuery.get();
      if (usersPage.empty) break;

      for (const userDoc of usersPage.docs) {
        const user = userDoc.data();
        const to = user.email as string | undefined;
        if (!to || !EMAIL_PATTERN.test(to)) continue;

        const displayName = escapeHtml((user.displayName as string | undefined) ?? "there");
        const completedCount = Array.isArray(user.progress?.completedTasks)
          ? user.progress.completedTasks.filter((taskId: unknown) => typeof taskId === "string").length
          : 0;

        const totalTasks = Number(user.progress?.totalTasks ?? 0);
        const percent = totalTasks > 0 ? Math.round((completedCount / totalTasks) * 100) : 0;

        const safeAppURL = sanitizeURL(appURL());
        const unsubscribeURL = buildWeeklyDigestUnsubscribeURL(userDoc.id);
        const safeUnsubscribeURL = sanitizeURL(unsubscribeURL ?? `${appURL()}/settings/notifications`);
        const html = `
        <div style="font-family:-apple-system,Arial,sans-serif;line-height:1.5;color:#111827;">
          <h2>Your Weekly Progress</h2>
          <p>Hi ${displayName},</p>
          <p>You have completed <b>${completedCount}</b> tasks so far (${percent}%).</p>
          <p><a href="${safeAppURL}" style="display:inline-block;padding:10px 16px;border-radius:8px;background:#6366F1;color:#fff;text-decoration:none;">Continue</a></p>
          <p style="margin-top:16px;font-size:12px;color:#6b7280;">
            To stop weekly digest emails, <a href="${safeUnsubscribeURL}">unsubscribe here</a>.
          </p>
        </div>
        `.trim();

        pendingSends.push((async () => {
          try {
            await sendMail({
              to,
              from: fromEmail(),
              subject: "Your weekly checklist digest",
              html,
              headers: unsubscribeURL
                ? {
                    "List-Unsubscribe": `<${unsubscribeURL}>`,
                    "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
                  }
                : undefined,
            });
          } catch (error) {
            functions.logger.error("Failed to send weekly digest", {
              userId: userDoc.id,
              toDomain: extractEmailDomain(to),
              error: error instanceof Error ? error.message : "unknown_error",
            });
          }
        })());

        totalRecipients += 1;

        if (pendingSends.length >= maxConcurrentSends) {
          await flushPending();
        }
      }

      lastDoc = usersPage.docs[usersPage.docs.length - 1];
      if (usersPage.size < pageSize) break;
    }

    await flushPending();
    functions.logger.info("Weekly digest batch complete", { totalRecipients });
    return null;
  });

export const sendSupportTicketConfirmation = emailRuntime.firestore
  .document("support/tickets/items/{ticketId}")
  .onCreate(async (snapshot, context) => {
    const ticket = snapshot.data();
    const userId = ticket.userId as string | undefined;
    if (!userId) return;

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const to = userData?.email as string | undefined;
    if (!to || !EMAIL_PATTERN.test(to)) return;

    try {
      await sendMail({
        to,
        from: fromEmail(),
        subject: `Support ticket #${context.params.ticketId} created`,
        html: supportCreatedHTML(
          (userData?.displayName as string | undefined) ?? "there",
          context.params.ticketId,
          (ticket.subject as string | undefined) ?? "Support request"
        ),
      });
    } catch (error) {
      functions.logger.error("Failed to send support ticket confirmation", {
        ticketId: context.params.ticketId,
        toDomain: extractEmailDomain(to),
        error: error instanceof Error ? error.message : "unknown_error",
      });
    }
  });

export const sendCustomEmail = emailRuntime.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  assertCallableAppCheck(context, "sendCustomEmail");

  if (!await isPrivilegedCaller(context, db)) {
    throw new functions.https.HttpsError("permission-denied", "Admin privileges required");
  }

  const to = safeString(data?.to);
  const templateKey = safeString(data?.templateKey).toLowerCase();
  const variables = parseTemplateVariables(data?.variables);

  if (!to || !templateKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Fields `to` and `templateKey` are required"
    );
  }

  if (!EMAIL_PATTERN.test(to)) {
    throw new functions.https.HttpsError("invalid-argument", "Recipient email is invalid");
  }

  if (!ALLOWED_CUSTOM_EMAIL_TEMPLATES.has(templateKey)) {
    throw new functions.https.HttpsError("invalid-argument", "Unsupported email template key");
  }

  const configuredFromEmail = fromEmail();
  if (!EMAIL_PATTERN.test(configuredFromEmail)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SENDGRID_FROM_EMAIL is missing or invalid"
    );
  }

  // Fail fast for admin-triggered emails if email provider is not configured.
  if (!getSendGridClient()) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SendGrid is not configured on this environment"
    );
  }

  await enforceRateLimit({
    db,
    namespace: "custom_email",
    userId: context.auth.uid,
    maxRequests: CUSTOM_EMAIL_RATE_LIMIT_MAX,
    windowMs: CUSTOM_EMAIL_RATE_LIMIT_WINDOW_MS,
    errorMessage: "Rate limit exceeded for custom email sending.",
  });

  const rendered = renderCustomTemplate(templateKey, variables);
  await writeCustomEmailAudit(context.auth.uid, templateKey, to, "attempted");

  try {
    await sendMail({
      to,
      from: configuredFromEmail,
      subject: rendered.subject,
      html: rendered.html,
    });
    await writeCustomEmailAudit(context.auth.uid, templateKey, to, "sent");
    return {
      success: true,
      templateKey,
    };
  } catch (error) {
    const errorCode = error instanceof Error ? error.name : "unknown_error";
    await writeCustomEmailAudit(context.auth.uid, templateKey, to, "failed", errorCode);
    functions.logger.error("Failed to send custom email", {
      userId: context.auth.uid,
      templateKey,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});

export const unsubscribeWeeklyDigest = emailRuntime.https.onRequest(async (request, response) => {
  if (request.method !== "GET" && request.method !== "POST") {
    response.status(405).send("Method not allowed");
    return;
  }

  const userId = safeString(request.query.uid);
  const issuedAt = safeString(request.query.ts);
  const signature = safeString(request.query.sig);

  if (!isValidUnsubscribeRequest(userId, issuedAt, signature)) {
    response.status(400).send("Invalid or expired unsubscribe link.");
    return;
  }

  try {
    await db.collection("users").doc(userId).set({
      preferences: {
        notifications: {
          weeklyDigest: false,
        },
      },
      metadata: {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });

    response
      .status(200)
      .setHeader("Content-Type", "text/html; charset=utf-8")
      .send(`
        <html>
          <body style="font-family:-apple-system,Arial,sans-serif;padding:24px;color:#111827;">
            <h2>Unsubscribed</h2>
            <p>You will no longer receive weekly digest emails from Arrival UK.</p>
            <p>If this was a mistake, you can re-enable digest emails in app settings.</p>
          </body>
        </html>
      `.trim());
  } catch (error) {
    functions.logger.error("Failed to unsubscribe weekly digest", {
      userId,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    response.status(500).send("Could not update email preferences. Please try again later.");
  }
});

export const __private__ = {
  parseTemplateVariables,
  MAX_TEMPLATE_VARIABLES,
  MAX_TEMPLATE_VARIABLE_KEY_LENGTH,
  MAX_TEMPLATE_VARIABLE_VALUE_LENGTH,
  buildWeeklyDigestUnsubscribeURL,
  isValidUnsubscribeRequest,
  signUnsubscribePayload,
};
