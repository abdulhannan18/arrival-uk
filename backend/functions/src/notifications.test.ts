import assert from "node:assert/strict";
import test from "node:test";
import { __private__ } from "./notifications";

test("normalizedPlatform accepts allowed values case-insensitively", () => {
  assert.equal(__private__.normalizedPlatform("iOS"), "ios");
  assert.equal(__private__.normalizedPlatform("ANDROID"), "android");
  assert.equal(__private__.normalizedPlatform("web"), "web");
});

test("normalizedPlatform rejects unsupported values", () => {
  assert.equal(__private__.normalizedPlatform("windows"), null);
  assert.equal(__private__.normalizedPlatform(""), null);
  assert.equal(__private__.normalizedPlatform(undefined), null);
});

test("normalizedAppVersion normalizes valid values and falls back for invalid", () => {
  assert.equal(__private__.normalizedAppVersion("1.2.3"), "1.2.3");
  assert.equal(__private__.normalizedAppVersion("2026.02-build_7"), "2026.02-build_7");
  assert.equal(__private__.normalizedAppVersion(""), "unknown");
  assert.equal(__private__.normalizedAppVersion("invalid version!"), "unknown");
  assert.equal(__private__.normalizedAppVersion(undefined), "unknown");
});

test("normalizedDeviceID accepts safe identifiers and rejects invalid formats", () => {
  assert.equal(__private__.normalizedDeviceID("ios-device_01"), "ios-device_01");
  assert.equal(__private__.normalizedDeviceID("  vendor:ABC-123  "), "vendor:ABC-123");
  assert.equal(__private__.normalizedDeviceID(""), null);
  assert.equal(__private__.normalizedDeviceID("device id with spaces"), null);
  assert.equal(__private__.normalizedDeviceID(undefined), null);
});

test("retryDelayMsForAttempt applies bounded exponential schedule", () => {
  assert.equal(__private__.retryDelayMsForAttempt(1), 5 * 60 * 1000);
  assert.equal(__private__.retryDelayMsForAttempt(2), 15 * 60 * 1000);
  assert.equal(__private__.retryDelayMsForAttempt(3), 60 * 60 * 1000);
  assert.equal(__private__.retryDelayMsForAttempt(50), 720 * 60 * 1000);
});

test("isPermanentMessagingErrorCode only flags known non-retryable messaging codes", () => {
  assert.equal(__private__.isPermanentMessagingErrorCode("messaging/invalid-registration-token"), true);
  assert.equal(__private__.isPermanentMessagingErrorCode("messaging/registration-token-not-registered"), true);
  assert.equal(__private__.isPermanentMessagingErrorCode("messaging/internal-error"), false);
  assert.equal(__private__.isPermanentMessagingErrorCode(null), false);
});

test("parseTimingToDays supports week/month timing variants", () => {
  assert.equal(__private__.parseTimingToDays("first week"), 7);
  assert.equal(__private__.parseTimingToDays("first_week"), 7);
  assert.equal(__private__.parseTimingToDays("first month"), 30);
  assert.equal(__private__.parseTimingToDays("first_month"), 30);
  assert.equal(__private__.parseTimingToDays("1 week before arrival"), 7);
  assert.equal(__private__.parseTimingToDays("1 month before arrival"), 30);
  assert.equal(__private__.parseTimingToDays("anytime"), 0);
});

test("notification dropped on error path is logged", () => {
  const payload = __private__.buildNotificationAttemptLog(
    "notif_123",
    "user_123",
    "task_reminder",
    "failure",
    "messaging/internal-error"
  );

  assert.equal(payload.notificationId, "notif_123");
  assert.equal(payload.userId, "user_123");
  assert.equal(payload.type, "task_reminder");
  assert.equal(payload.channel, "push");
  assert.equal(payload.result, "failure");
  assert.equal(payload.error, "messaging/internal-error");
});

test("duplicate notification blocked by idempotency key", () => {
  const sendAt = new Date("2026-03-20T09:00:00.000Z");
  const first = __private__.queueDocumentID("user_123", "task_abc", sendAt);
  const second = __private__.queueDocumentID("user_123", "task_abc", sendAt);
  const third = __private__.queueDocumentID("user_123", "task_xyz", sendAt);

  assert.equal(first, second);
  assert.notEqual(first, third);
});

test("stale push token removed on invalid registration", () => {
  const invalidTokens = __private__.invalidTokensFromMessagingResponses(
    ["good-token", "stale-token", "retry-token"],
    [
      { success: true },
      { success: false, error: { code: "messaging/registration-token-not-registered" } },
      { success: false, error: { code: "messaging/internal-error" } },
    ]
  );

  assert.deepEqual(invalidTokens, ["stale-token"]);
});
