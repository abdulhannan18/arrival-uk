import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { isPrivilegedCaller } from "./utils/privileged";
import { enforceRateLimit } from "./utils/rateLimit";
import { assertCallableAppCheck } from "./utils/appCheck";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const SMS_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const SMS_RATE_LIMIT_MAX = 10;
const E164_PHONE_PATTERN = /^\+[1-9]\d{7,14}$/;
const TWILIO_ACCOUNT_SID_SECRET = "TWILIO_ACCOUNT_SID";
const TWILIO_AUTH_TOKEN_SECRET = "TWILIO_AUTH_TOKEN";
const TWILIO_PHONE_NUMBER_SECRET = "TWILIO_PHONE_NUMBER";
let didWarnInvalidSenderPhone = false;
const smsRuntime = functions.runWith({
  secrets: [
    TWILIO_ACCOUNT_SID_SECRET,
    TWILIO_AUTH_TOKEN_SECRET,
    TWILIO_PHONE_NUMBER_SECRET,
  ],
});

type TwilioClient = {
  messages: {
    create: (args: { body: string; from: string; to: string }) => Promise<{ sid: string }>;
  };
};

type SMSReminderDependencies = {
  assertCallableAppCheck: typeof assertCallableAppCheck;
  isPrivilegedCaller: typeof isPrivilegedCaller;
  enforceRateLimit: typeof enforceRateLimit;
  getTwilioClient: () => TwilioClient | null;
  fromPhone: () => string | null;
};

let cachedTwilioClient: TwilioClient | null | undefined;

function getTwilioClient(): TwilioClient | null {
  if (cachedTwilioClient !== undefined) {
    return cachedTwilioClient;
  }

  try {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    if (!accountSid || !authToken) {
      cachedTwilioClient = null;
      return cachedTwilioClient;
    }

    // Optional runtime dependency.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const twilioFactory = require("twilio") as (sid: string, token: string) => TwilioClient;
    cachedTwilioClient = twilioFactory(accountSid, authToken);
    return cachedTwilioClient;
  } catch {
    cachedTwilioClient = null;
    return cachedTwilioClient;
  }
}

function fromPhone(): string | null {
  const value = process.env.TWILIO_PHONE_NUMBER;
  const normalized = value?.trim() ?? "";
  if (!normalized) return null;
  if (E164_PHONE_PATTERN.test(normalized)) {
    return normalized;
  }

  if (!didWarnInvalidSenderPhone) {
    didWarnInvalidSenderPhone = true;
    functions.logger.warn("Invalid TWILIO_PHONE_NUMBER. SMS sending disabled until corrected.");
  }

  return null;
}

function safeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function isValidE164Phone(value: string): boolean {
  return E164_PHONE_PATTERN.test(value);
}

function redactPhone(value: string): string {
  if (value.length <= 6) {
    return "***";
  }

  const suffix = value.slice(-4);
  return `***${suffix}`;
}

const defaultSMSReminderDependencies: SMSReminderDependencies = {
  assertCallableAppCheck,
  isPrivilegedCaller,
  enforceRateLimit,
  getTwilioClient,
  fromPhone,
};

async function sendSMSReminderImpl(
  data: unknown,
  context: functions.https.CallableContext,
  dependencies: SMSReminderDependencies = defaultSMSReminderDependencies
): Promise<{ success: true; sid: string }> {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  dependencies.assertCallableAppCheck(context, "sendSMSReminder");

  if (!await dependencies.isPrivilegedCaller(context, db)) {
    throw new functions.https.HttpsError("permission-denied", "Admin privileges required");
  }

  const to = safeString((data as { phoneNumber?: unknown })?.phoneNumber);
  const body = safeString((data as { message?: unknown })?.message);

  if (!to || !body) {
    throw new functions.https.HttpsError("invalid-argument", "phoneNumber and message are required");
  }

  if (!isValidE164Phone(to)) {
    throw new functions.https.HttpsError("invalid-argument", "phoneNumber must be E.164 format");
  }

  if (body.length > 320) {
    throw new functions.https.HttpsError("invalid-argument", "message exceeds maximum length");
  }

  await dependencies.enforceRateLimit({
    db,
    namespace: "custom_sms",
    userId: context.auth.uid,
    maxRequests: SMS_RATE_LIMIT_MAX,
    windowMs: SMS_RATE_LIMIT_WINDOW_MS,
    errorMessage: "Rate limit exceeded for SMS sending.",
  });

  const client = dependencies.getTwilioClient();
  const from = dependencies.fromPhone();

  if (!client || !from) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Twilio is not configured on this environment"
    );
  }

  try {
    const result = await client.messages.create({
      body,
      from,
      to,
    });
    return { success: true, sid: result.sid };
  } catch (error) {
    functions.logger.error("SMS send failed", {
      toRedacted: redactPhone(to),
      userId: context.auth.uid,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    throw new functions.https.HttpsError("internal", "Failed to send SMS");
  }
}

export const sendSMSReminder = smsRuntime.https.onCall(async (data, context) => {
  return sendSMSReminderImpl(data, context);
});

export const __private__ = {
  isValidE164Phone,
  redactPhone,
  sendSMSReminderImpl,
  resetTwilioClientCache: () => {
    cachedTwilioClient = undefined;
  },
};
