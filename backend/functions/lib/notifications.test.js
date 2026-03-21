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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const admin = __importStar(require("firebase-admin"));
const notifications_1 = require("./notifications");
(0, node_test_1.default)("normalizedPlatform accepts allowed values case-insensitively", () => {
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform("iOS"), "ios");
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform("ANDROID"), "android");
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform("web"), "web");
});
(0, node_test_1.default)("normalizedPlatform rejects unsupported values", () => {
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform("windows"), null);
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform(""), null);
    strict_1.default.equal(notifications_1.__private__.normalizedPlatform(undefined), null);
});
(0, node_test_1.default)("normalizedAppVersion normalizes valid values and falls back for invalid", () => {
    strict_1.default.equal(notifications_1.__private__.normalizedAppVersion("1.2.3"), "1.2.3");
    strict_1.default.equal(notifications_1.__private__.normalizedAppVersion("2026.02-build_7"), "2026.02-build_7");
    strict_1.default.equal(notifications_1.__private__.normalizedAppVersion(""), "unknown");
    strict_1.default.equal(notifications_1.__private__.normalizedAppVersion("invalid version!"), "unknown");
    strict_1.default.equal(notifications_1.__private__.normalizedAppVersion(undefined), "unknown");
});
(0, node_test_1.default)("normalizedDeviceID accepts safe identifiers and rejects invalid formats", () => {
    strict_1.default.equal(notifications_1.__private__.normalizedDeviceID("ios-device_01"), "ios-device_01");
    strict_1.default.equal(notifications_1.__private__.normalizedDeviceID("  vendor:ABC-123  "), "vendor:ABC-123");
    strict_1.default.equal(notifications_1.__private__.normalizedDeviceID(""), null);
    strict_1.default.equal(notifications_1.__private__.normalizedDeviceID("device id with spaces"), null);
    strict_1.default.equal(notifications_1.__private__.normalizedDeviceID(undefined), null);
});
(0, node_test_1.default)("retryDelayMsForAttempt applies bounded exponential schedule", () => {
    strict_1.default.equal(notifications_1.__private__.retryDelayMsForAttempt(1), 5 * 60 * 1000);
    strict_1.default.equal(notifications_1.__private__.retryDelayMsForAttempt(2), 15 * 60 * 1000);
    strict_1.default.equal(notifications_1.__private__.retryDelayMsForAttempt(3), 60 * 60 * 1000);
    strict_1.default.equal(notifications_1.__private__.retryDelayMsForAttempt(50), 720 * 60 * 1000);
});
(0, node_test_1.default)("isPermanentMessagingErrorCode only flags known non-retryable messaging codes", () => {
    strict_1.default.equal(notifications_1.__private__.isPermanentMessagingErrorCode("messaging/invalid-registration-token"), true);
    strict_1.default.equal(notifications_1.__private__.isPermanentMessagingErrorCode("messaging/registration-token-not-registered"), true);
    strict_1.default.equal(notifications_1.__private__.isPermanentMessagingErrorCode("messaging/internal-error"), false);
    strict_1.default.equal(notifications_1.__private__.isPermanentMessagingErrorCode(null), false);
});
(0, node_test_1.default)("parseTimingToDays supports week/month timing variants", () => {
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("first week"), 7);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("first_week"), 7);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("first month"), 30);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("first_month"), 30);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("1 week before arrival"), 7);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("1 month before arrival"), 30);
    strict_1.default.equal(notifications_1.__private__.parseTimingToDays("anytime"), 0);
});
(0, node_test_1.default)("notification dropped on error path is logged", () => {
    const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
    process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";
    try {
        const payload = notifications_1.__private__.buildNotificationAttemptLog("notif_123", "user_123", "task_reminder", "failure", "messaging/internal-error");
        strict_1.default.equal(payload.type, "task_reminder");
        strict_1.default.equal(payload.channel, "push");
        strict_1.default.equal(payload.result, "failure");
        strict_1.default.equal(payload.error, "messaging/internal-error");
        strict_1.default.match(String(payload.notificationRef), /^notif:[0-9a-f]{12}$/);
        strict_1.default.match(String(payload.userRef), /^uid:[0-9a-f]{12}$/);
    }
    finally {
        if (previousKey === undefined) {
            delete process.env.LOG_PSEUDONYMIZATION_KEY;
        }
        else {
            process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
        }
    }
});
(0, node_test_1.default)("duplicate notification blocked by idempotency key", () => {
    const sendAt = new Date("2026-03-20T09:00:00.000Z");
    const first = notifications_1.__private__.queueDocumentID("user_123", "task_abc", sendAt);
    const second = notifications_1.__private__.queueDocumentID("user_123", "task_abc", sendAt);
    const third = notifications_1.__private__.queueDocumentID("user_123", "task_xyz", sendAt);
    strict_1.default.equal(first, second);
    strict_1.default.notEqual(first, third);
});
(0, node_test_1.default)("stale push token removed on invalid registration", () => {
    const invalidTokens = notifications_1.__private__.invalidTokensFromMessagingResponses(["good-token", "stale-token", "retry-token"], [
        { success: true },
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
        { success: false, error: { code: "messaging/internal-error" } },
    ]);
    strict_1.default.deepEqual(invalidTokens, ["stale-token"]);
});
(0, node_test_1.default)("log output does not contain raw user id", () => {
    const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
    process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";
    try {
        const payload = notifications_1.__private__.buildNotificationAttemptLog("notif_123", "user_123", "task_reminder", "failure", "messaging/internal-error");
        const serialized = JSON.stringify(payload);
        strict_1.default.equal(serialized.includes("user_123"), false);
        strict_1.default.equal(serialized.includes("notif_123"), false);
        strict_1.default.match(serialized, /uid:[0-9a-f]{12}/);
        strict_1.default.match(serialized, /notif:[0-9a-f]{12}/);
    }
    finally {
        if (previousKey === undefined) {
            delete process.env.LOG_PSEUDONYMIZATION_KEY;
        }
        else {
            process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
        }
    }
});
(0, node_test_1.default)("dead letter written after max retries", async () => {
    const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
    process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";
    try {
        const updates = [];
        let capturedID = "";
        let capturedRecord;
        const firstAttemptAt = admin.firestore.Timestamp.fromDate(new Date("2026-03-20T09:00:00.000Z"));
        const deadLetteredAt = admin.firestore.Timestamp.fromDate(new Date("2026-03-20T12:00:00.000Z"));
        await notifications_1.__private__.persistTerminalNotificationFailure({
            update: async (payload) => {
                updates.push(payload);
            },
        }, "notif_123", {
            userId: "user_123",
            type: "task_reminder",
            title: "Task reminder",
            body: "Bring your passport.",
            data: { type: "task_reminder", taskId: "task_123" },
            scheduledFor: firstAttemptAt,
            sent: false,
        }, 5, "messaging/internal-error", "messaging/internal-error", {
            doc: (id) => ({
                set: async (record) => {
                    capturedID = id;
                    capturedRecord = record;
                },
            }),
        }, deadLetteredAt);
        strict_1.default.equal(updates.length, 1);
        strict_1.default.equal(capturedID, "notif_123");
        strict_1.default.equal(capturedRecord?.notificationId, "notif_123");
        strict_1.default.equal(capturedRecord?.notificationType, "task_reminder");
        strict_1.default.equal(capturedRecord?.attemptCount, 5);
        strict_1.default.equal(capturedRecord?.failureCode, "messaging/internal-error");
        strict_1.default.equal(capturedRecord?.failureReason, "messaging/internal-error");
        strict_1.default.equal(capturedRecord?.deadLetteredAt, deadLetteredAt);
        strict_1.default.equal(capturedRecord?.firstAttemptAt, firstAttemptAt);
        strict_1.default.equal(String(capturedRecord?.userId).includes("user_123"), false);
        strict_1.default.match(String(capturedRecord?.userId), /^uid:[0-9a-f]{12}$/);
    }
    finally {
        if (previousKey === undefined) {
            delete process.env.LOG_PSEUDONYMIZATION_KEY;
        }
        else {
            process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
        }
    }
});
(0, node_test_1.default)("dead letter write failure does not throw", async () => {
    let updateCalls = 0;
    await notifications_1.__private__.persistTerminalNotificationFailure({
        update: async () => {
            updateCalls += 1;
        },
    }, "notif_123", {
        userId: "user_123",
        type: "task_reminder",
        title: "Task reminder",
        body: "Bring your passport.",
        data: { type: "task_reminder", taskId: "task_123" },
        scheduledFor: admin.firestore.Timestamp.fromDate(new Date("2026-03-20T09:00:00.000Z")),
        sent: false,
    }, 5, "messaging/internal-error", "messaging/internal-error", {
        doc: () => ({
            set: async () => {
                throw new Error("firestore unavailable");
            },
        }),
    }, admin.firestore.Timestamp.fromDate(new Date("2026-03-20T12:00:00.000Z")));
    strict_1.default.equal(updateCalls, 1);
});
//# sourceMappingURL=notifications.test.js.map