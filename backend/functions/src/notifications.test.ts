import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
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
  const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
  process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";

  try {
    const payload = __private__.buildNotificationAttemptLog(
      "notif_123",
      "user_123",
      "task_reminder",
      "failure",
      "messaging/internal-error"
    );

    assert.equal(payload.type, "task_reminder");
    assert.equal(payload.channel, "push");
    assert.equal(payload.result, "failure");
    assert.equal(payload.error, "messaging/internal-error");
    assert.match(String(payload.notificationRef), /^notif:[0-9a-f]{12}$/);
    assert.match(String(payload.userRef), /^uid:[0-9a-f]{12}$/);
  } finally {
    if (previousKey === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
    }
  }
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


test("log output does not contain raw user id", () => {
  const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
  process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";

  try {
    const payload = __private__.buildNotificationAttemptLog(
      "notif_123",
      "user_123",
      "task_reminder",
      "failure",
      "messaging/internal-error"
    );

    const serialized = JSON.stringify(payload);
    assert.equal(serialized.includes("user_123"), false);
    assert.equal(serialized.includes("notif_123"), false);
    assert.match(serialized, /uid:[0-9a-f]{12}/);
    assert.match(serialized, /notif:[0-9a-f]{12}/);
  } finally {
    if (previousKey === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
    }
  }
});

test("dead letter written after max retries", async () => {
  const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
  process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";

  try {
    const updates: Record<string, unknown>[] = [];
    let capturedID = "";
    let capturedRecord: Record<string, unknown> | undefined;
    const firstAttemptAt = admin.firestore.Timestamp.fromDate(new Date("2026-03-20T09:00:00.000Z"));
    const deadLetteredAt = admin.firestore.Timestamp.fromDate(new Date("2026-03-20T12:00:00.000Z"));

    await __private__.persistTerminalNotificationFailure(
      {
        update: async (payload: Record<string, unknown>) => {
          updates.push(payload);
        },
      },
      "notif_123",
      {
        userId: "user_123",
        type: "task_reminder",
        title: "Task reminder",
        body: "Bring your passport.",
        data: { type: "task_reminder", taskId: "task_123" },
        scheduledFor: firstAttemptAt,
        sent: false,
      },
      5,
      "messaging/internal-error",
      "messaging/internal-error",
      {
        doc: (id: string) => ({
          set: async (record: Record<string, unknown>) => {
            capturedID = id;
            capturedRecord = record;
          },
        }),
      },
      deadLetteredAt
    );

    assert.equal(updates.length, 1);
    assert.equal(capturedID, "notif_123");
    assert.equal(capturedRecord?.notificationId, "notif_123");
    assert.equal(capturedRecord?.notificationType, "task_reminder");
    assert.equal(capturedRecord?.attemptCount, 5);
    assert.equal(capturedRecord?.failureCode, "messaging/internal-error");
    assert.equal(capturedRecord?.failureReason, "messaging/internal-error");
    assert.equal(capturedRecord?.deadLetteredAt, deadLetteredAt);
    assert.equal(capturedRecord?.firstAttemptAt, firstAttemptAt);
    assert.equal(String(capturedRecord?.userId).includes("user_123"), false);
    assert.match(String(capturedRecord?.userId), /^uid:[0-9a-f]{12}$/);
  } finally {
    if (previousKey === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previousKey;
    }
  }
});

test("dead letter write failure does not throw", async () => {
  let updateCalls = 0;

  await __private__.persistTerminalNotificationFailure(
    {
      update: async () => {
        updateCalls += 1;
      },
    },
    "notif_123",
    {
      userId: "user_123",
      type: "task_reminder",
      title: "Task reminder",
      body: "Bring your passport.",
      data: { type: "task_reminder", taskId: "task_123" },
      scheduledFor: admin.firestore.Timestamp.fromDate(new Date("2026-03-20T09:00:00.000Z")),
      sent: false,
    },
    5,
    "messaging/internal-error",
    "messaging/internal-error",
    {
      doc: () => ({
        set: async () => {
          throw new Error("firestore unavailable");
        },
      }),
    },
    admin.firestore.Timestamp.fromDate(new Date("2026-03-20T12:00:00.000Z"))
  );

  assert.equal(updateCalls, 1);
});
