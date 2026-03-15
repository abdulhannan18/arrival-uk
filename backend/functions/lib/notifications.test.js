"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
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
//# sourceMappingURL=notifications.test.js.map