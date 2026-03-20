import test from "node:test";
import assert from "node:assert/strict";
import { __private__ } from "./email";

test("parseTemplateVariables ignores non-strings and enforces limits", () => {
  const raw = {
    recipientName: "  Student  ",
    message: "Hello",
    ignoredNumber: 42,
    ignoredArray: ["a", "b"],
  } as unknown;

  const parsed = __private__.parseTemplateVariables(raw);
  assert.deepEqual(parsed, {
    recipientName: "Student",
    message: "Hello",
  });
});

test("parseTemplateVariables caps entry count and trims oversized key/value", () => {
  const oversizedKey = "k".repeat(__private__.MAX_TEMPLATE_VARIABLE_KEY_LENGTH + 40);
  const oversizedValue = "v".repeat(__private__.MAX_TEMPLATE_VARIABLE_VALUE_LENGTH + 200);

  const raw: Record<string, string> = {};
  raw[oversizedKey] = oversizedValue;
  for (let index = 0; index < __private__.MAX_TEMPLATE_VARIABLES + 5; index += 1) {
    raw[`key_${index}`] = `value_${index}`;
  }

  const parsed = __private__.parseTemplateVariables(raw);
  const entries = Object.entries(parsed);

  assert.equal(entries.length, __private__.MAX_TEMPLATE_VARIABLES);
  const [firstKey, firstValue] = entries[0];
  assert.equal(firstKey.length, __private__.MAX_TEMPLATE_VARIABLE_KEY_LENGTH);
  assert.equal(firstValue.length, __private__.MAX_TEMPLATE_VARIABLE_VALUE_LENGTH);
});

test("weekly digest unsubscribe URL is signed and validates", () => {
  const previousSecret = process.env.UNSUBSCRIBE_HMAC_SECRET;
  process.env.UNSUBSCRIBE_HMAC_SECRET = "test-unsubscribe-secret";

  try {
    const nowMs = 1_725_000_000_000;
    const userId = "testUser123";
    const urlString = __private__.buildWeeklyDigestUnsubscribeURL(userId, nowMs);
    assert.ok(urlString);

    const parsed = new URL(urlString!);
    const uid = parsed.searchParams.get("uid");
    const emailType = parsed.searchParams.get("type");
    const ts = parsed.searchParams.get("ts");
    const sig = parsed.searchParams.get("sig");
    assert.equal(uid, userId);
    assert.equal(emailType, __private__.WEEKLY_DIGEST_EMAIL_TYPE);
    assert.equal(ts, String(nowMs));
    assert.ok(sig);

    assert.equal(
      __private__.isValidUnsubscribeRequest(
        uid!,
        emailType!,
        ts!,
        sig!,
        nowMs + 1_000,
        "test-unsubscribe-secret"
      ),
      true
    );
    assert.equal(
      __private__.isValidUnsubscribeRequest(
        uid!,
        emailType!,
        ts!,
        `${sig}tampered`,
        nowMs + 1_000,
        "test-unsubscribe-secret"
      ),
      false
    );
  } finally {
    if (previousSecret === undefined) {
      delete process.env.UNSUBSCRIBE_HMAC_SECRET;
    } else {
      process.env.UNSUBSCRIBE_HMAC_SECRET = previousSecret;
    }
  }
});

test("unsubscribe link token cannot be used for another user", () => {
  const previousSecret = process.env.UNSUBSCRIBE_HMAC_SECRET;
  process.env.UNSUBSCRIBE_HMAC_SECRET = "test-unsubscribe-secret";

  try {
    const nowMs = 1_725_000_000_000;
    const urlString = __private__.buildWeeklyDigestUnsubscribeURL("testUser123", nowMs);
    assert.ok(urlString);

    const parsed = new URL(urlString!);
    const emailType = parsed.searchParams.get("type");
    const ts = parsed.searchParams.get("ts");
    const sig = parsed.searchParams.get("sig");

    assert.equal(
      __private__.isValidUnsubscribeRequest(
        "differentUser456",
        emailType!,
        ts!,
        sig!,
        nowMs + 1_000,
        "test-unsubscribe-secret"
      ),
      false
    );
  } finally {
    if (previousSecret === undefined) {
      delete process.env.UNSUBSCRIBE_HMAC_SECRET;
    } else {
      process.env.UNSUBSCRIBE_HMAC_SECRET = previousSecret;
    }
  }
});

test("unsubscribe get renders confirmation not executes", () => {
  const html = __private__.renderWeeklyDigestUnsubscribeConfirmation(
    "testUser123",
    __private__.WEEKLY_DIGEST_EMAIL_TYPE,
    "1725000000000",
    "signature"
  );

  assert.match(html, /<form method="POST">/);
  assert.match(html, /Confirm unsubscribe/);
  assert.doesNotMatch(html, /You will no longer receive weekly digest emails/);
});

test("digest not sent twice in same week", () => {
  const firstWindow = __private__.weeklyDigestWindowKey(new Date("2026-03-16T09:00:00.000Z"));
  const secondWindow = __private__.weeklyDigestWindowKey(new Date("2026-03-18T12:00:00.000Z"));

  assert.equal(firstWindow, secondWindow);
  assert.equal(
    __private__.weeklyDigestIdempotencyKey("user_123", firstWindow),
    __private__.weeklyDigestIdempotencyKey("user_123", secondWindow)
  );
  assert.equal(__private__.digestReservationAction("sent"), "skip");
  assert.equal(__private__.digestReservationAction("reserved"), "skip");
});

test("digest retry succeeds when previous send failed", () => {
  assert.equal(__private__.digestReservationAction("failed"), "reserve");
  assert.equal(__private__.digestReservationAction(null), "reserve");
});
