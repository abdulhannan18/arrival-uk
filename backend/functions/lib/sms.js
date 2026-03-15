"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.__private__ = exports.sendSMSReminder = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const privileged_1 = require("./utils/privileged");
const rateLimit_1 = require("./utils/rateLimit");
const appCheck_1 = require("./utils/appCheck");
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
let cachedTwilioClient;
function getTwilioClient() {
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
        const twilioFactory = require("twilio");
        cachedTwilioClient = twilioFactory(accountSid, authToken);
        return cachedTwilioClient;
    }
    catch {
        cachedTwilioClient = null;
        return cachedTwilioClient;
    }
}
function fromPhone() {
    const value = process.env.TWILIO_PHONE_NUMBER;
    const normalized = value?.trim() ?? "";
    if (!normalized)
        return null;
    if (E164_PHONE_PATTERN.test(normalized)) {
        return normalized;
    }
    if (!didWarnInvalidSenderPhone) {
        didWarnInvalidSenderPhone = true;
        functions.logger.warn("Invalid TWILIO_PHONE_NUMBER. SMS sending disabled until corrected.");
    }
    return null;
}
function safeString(value) {
    return typeof value === "string" ? value.trim() : "";
}
function isValidE164Phone(value) {
    return E164_PHONE_PATTERN.test(value);
}
function redactPhone(value) {
    if (value.length <= 6) {
        return "***";
    }
    const suffix = value.slice(-4);
    return `***${suffix}`;
}
const defaultSMSReminderDependencies = {
    assertCallableAppCheck: appCheck_1.assertCallableAppCheck,
    isPrivilegedCaller: privileged_1.isPrivilegedCaller,
    enforceRateLimit: rateLimit_1.enforceRateLimit,
    getTwilioClient,
    fromPhone,
};
async function sendSMSReminderImpl(data, context, dependencies = defaultSMSReminderDependencies) {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    dependencies.assertCallableAppCheck(context, "sendSMSReminder");
    if (!await dependencies.isPrivilegedCaller(context, db)) {
        throw new functions.https.HttpsError("permission-denied", "Admin privileges required");
    }
    const to = safeString(data?.phoneNumber);
    const body = safeString(data?.message);
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
        throw new functions.https.HttpsError("failed-precondition", "Twilio is not configured on this environment");
    }
    try {
        const result = await client.messages.create({
            body,
            from,
            to,
        });
        return { success: true, sid: result.sid };
    }
    catch (error) {
        functions.logger.error("SMS send failed", {
            toRedacted: redactPhone(to),
            userId: context.auth.uid,
            error: error instanceof Error ? error.message : "unknown_error",
        });
        throw new functions.https.HttpsError("internal", "Failed to send SMS");
    }
}
exports.sendSMSReminder = smsRuntime.https.onCall(async (data, context) => {
    return sendSMSReminderImpl(data, context);
});
exports.__private__ = {
    isValidE164Phone,
    redactPhone,
    sendSMSReminderImpl,
    resetTwilioClientCache: () => {
        cachedTwilioClient = undefined;
    },
};
//# sourceMappingURL=sms.js.map