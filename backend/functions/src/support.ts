import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Collections } from "./constants";
import { enforceRateLimit } from "./utils/rateLimit";
import { assertCallableAppCheck } from "./utils/appCheck";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const SUPPORT_TICKET_RATE_LIMIT_MAX = 8;
const SUPPORT_TICKET_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const SUPPORT_MESSAGE_RATE_LIMIT_MAX = 40;
const SUPPORT_MESSAGE_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const MAX_SUBJECT_LENGTH = 160;
const MAX_MESSAGE_LENGTH = 4000;
const MAX_PRIORITY_LENGTH = 32;
const MAX_CATEGORY_LENGTH = 80;
const MAX_METADATA_ENTRIES = 20;
const MAX_METADATA_KEY_LENGTH = 40;
const MAX_METADATA_VALUE_LENGTH = 200;
const MAX_APP_VERSION_LENGTH = 32;
const APP_VERSION_PATTERN = /^[0-9A-Za-z._-]{1,32}$/;
const MAX_TICKET_ID_LENGTH = 128;
const ALLOWED_PLATFORMS = new Set(["ios", "android", "web"]);

type SupportMetadataValue = string | number | boolean;
type SupportMetadata = Record<string, SupportMetadataValue>;

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizedPlatform(value: unknown): string {
  const normalized = safeString(value).toLowerCase();
  if (!normalized || !ALLOWED_PLATFORMS.has(normalized)) {
    return "unknown";
  }
  return normalized;
}

function normalizedAppVersion(value: unknown): string {
  const normalized = safeString(value).slice(0, MAX_APP_VERSION_LENGTH);
  if (!normalized || !APP_VERSION_PATTERN.test(normalized)) {
    return "unknown";
  }
  return normalized;
}

function sanitizeSupportMetadata(value: unknown): SupportMetadata | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }

  const metadata: SupportMetadata = {};
  let accepted = 0;
  for (const [rawKey, rawValue] of Object.entries(value as Record<string, unknown>)) {
    if (accepted >= MAX_METADATA_ENTRIES) break;

    const key = rawKey.trim().slice(0, MAX_METADATA_KEY_LENGTH);
    if (!key) continue;

    if (typeof rawValue === "string") {
      metadata[key] = rawValue.slice(0, MAX_METADATA_VALUE_LENGTH);
      accepted += 1;
      continue;
    }

    if (typeof rawValue === "boolean") {
      metadata[key] = rawValue;
      accepted += 1;
      continue;
    }

    if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
      metadata[key] = rawValue;
      accepted += 1;
    }
  }

  return Object.keys(metadata).length > 0 ? metadata : undefined;
}

function validateRequiredTextField(value: unknown, fieldName: string, maxLength: number): string {
  const normalized = safeString(value);
  if (!normalized) {
    throw new functions.https.HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return normalized.slice(0, maxLength);
}

function validateOptionalTextField(value: unknown, maxLength: number): string | undefined {
  const normalized = safeString(value);
  if (!normalized) return undefined;
  return normalized.slice(0, maxLength);
}

function validateTicketID(value: unknown): string {
  const ticketID = safeString(value);
  if (!ticketID || ticketID.length > MAX_TICKET_ID_LENGTH || ticketID.includes("/")) {
    throw new functions.https.HttpsError("invalid-argument", "ticketId is invalid");
  }
  return ticketID;
}

function supportTicketCollection(): FirebaseFirestore.CollectionReference {
  return db
    .collection(Collections.support.root)
    .doc(Collections.support.tickets)
    .collection(Collections.support.items);
}

export const createSupportTicket = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  assertCallableAppCheck(context, "createSupportTicket");

  const userId = context.auth.uid;
  await enforceRateLimit({
    db,
    namespace: "support_ticket_create",
    userId,
    maxRequests: SUPPORT_TICKET_RATE_LIMIT_MAX,
    windowMs: SUPPORT_TICKET_RATE_LIMIT_WINDOW_MS,
    errorMessage: "Too many support requests. Please try again later.",
  });

  const subject = validateRequiredTextField(data?.subject, "subject", MAX_SUBJECT_LENGTH);
  const message = validateRequiredTextField(data?.message, "message", MAX_MESSAGE_LENGTH);
  const category = validateOptionalTextField(data?.category, MAX_CATEGORY_LENGTH);
  const priority = validateOptionalTextField(data?.priority, MAX_PRIORITY_LENGTH);
  const metadata = sanitizeSupportMetadata(data?.metadata) ?? {};
  metadata.platform = normalizedPlatform(data?.platform);
  metadata.appVersion = normalizedAppVersion(data?.appVersion);

  const ticketRef = supportTicketCollection().doc();
  const ticketPayload: Record<string, unknown> = {
    userId,
    subject,
    message,
    status: "open",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata,
  };
  if (category) ticketPayload.category = category;
  if (priority) ticketPayload.priority = priority;

  await ticketRef.set(ticketPayload);

  return {
    success: true,
    ticketId: ticketRef.id,
  };
});

export const addSupportTicketMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  assertCallableAppCheck(context, "addSupportTicketMessage");

  const userId = context.auth.uid;
  await enforceRateLimit({
    db,
    namespace: "support_ticket_message",
    userId,
    maxRequests: SUPPORT_MESSAGE_RATE_LIMIT_MAX,
    windowMs: SUPPORT_MESSAGE_RATE_LIMIT_WINDOW_MS,
    errorMessage: "Too many support messages. Please try again later.",
  });

  const ticketId = validateTicketID(data?.ticketId);
  const message = validateRequiredTextField(data?.message, "message", MAX_MESSAGE_LENGTH);
  const metadata = sanitizeSupportMetadata(data?.metadata) ?? {};
  metadata.platform = normalizedPlatform(data?.platform);
  metadata.appVersion = normalizedAppVersion(data?.appVersion);

  const ticketRef = supportTicketCollection().doc(ticketId);
  const messageRef = ticketRef.collection(Collections.support.messages).doc();

  await db.runTransaction(async (transaction) => {
    const ticketSnapshot = await transaction.get(ticketRef);
    if (!ticketSnapshot.exists) {
      throw new functions.https.HttpsError("not-found", "Support ticket not found");
    }

    const ticketOwnerID = safeString(ticketSnapshot.data()?.userId);
    if (ticketOwnerID != userId) {
      throw new functions.https.HttpsError("permission-denied", "You do not own this support ticket");
    }

    transaction.set(messageRef, {
      userId,
      message,
      senderType: "user",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata,
    });
    transaction.set(ticketRef, {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return {
    success: true,
    messageId: messageRef.id,
  };
});

export const __private__ = {
  normalizedPlatform,
  normalizedAppVersion,
  sanitizeSupportMetadata,
  validateTicketID,
};
