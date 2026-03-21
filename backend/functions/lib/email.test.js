"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const email_1 = require("./email");
(0, node_test_1.default)("parseTemplateVariables ignores non-strings and enforces limits", () => {
    const raw = {
        recipientName: "  Student  ",
        message: "Hello",
        ignoredNumber: 42,
        ignoredArray: ["a", "b"],
    };
    const parsed = email_1.__private__.parseTemplateVariables(raw);
    strict_1.default.deepEqual(parsed, {
        recipientName: "Student",
        message: "Hello",
    });
});
(0, node_test_1.default)("parseTemplateVariables caps entry count and trims oversized key/value", () => {
    const oversizedKey = "k".repeat(email_1.__private__.MAX_TEMPLATE_VARIABLE_KEY_LENGTH + 40);
    const oversizedValue = "v".repeat(email_1.__private__.MAX_TEMPLATE_VARIABLE_VALUE_LENGTH + 200);
    const raw = {};
    raw[oversizedKey] = oversizedValue;
    for (let index = 0; index < email_1.__private__.MAX_TEMPLATE_VARIABLES + 5; index += 1) {
        raw[`key_${index}`] = `value_${index}`;
    }
    const parsed = email_1.__private__.parseTemplateVariables(raw);
    const entries = Object.entries(parsed);
    strict_1.default.equal(entries.length, email_1.__private__.MAX_TEMPLATE_VARIABLES);
    const [firstKey, firstValue] = entries[0];
    strict_1.default.equal(firstKey.length, email_1.__private__.MAX_TEMPLATE_VARIABLE_KEY_LENGTH);
    strict_1.default.equal(firstValue.length, email_1.__private__.MAX_TEMPLATE_VARIABLE_VALUE_LENGTH);
});
(0, node_test_1.default)("weekly digest unsubscribe URL is signed and validates", () => {
    const previousSecret = process.env.UNSUBSCRIBE_HMAC_SECRET;
    process.env.UNSUBSCRIBE_HMAC_SECRET = "test-unsubscribe-secret";
    try {
        const nowMs = 1_725_000_000_000;
        const userId = "testUser123";
        const urlString = email_1.__private__.buildWeeklyDigestUnsubscribeURL(userId, nowMs);
        strict_1.default.ok(urlString);
        const parsed = new URL(urlString);
        const uid = parsed.searchParams.get("uid");
        const emailType = parsed.searchParams.get("type");
        const ts = parsed.searchParams.get("ts");
        const sig = parsed.searchParams.get("sig");
        strict_1.default.equal(uid, userId);
        strict_1.default.equal(emailType, email_1.__private__.WEEKLY_DIGEST_EMAIL_TYPE);
        strict_1.default.equal(ts, String(nowMs));
        strict_1.default.ok(sig);
        strict_1.default.equal(email_1.__private__.isValidUnsubscribeRequest(uid, emailType, ts, sig, nowMs + 1_000, "test-unsubscribe-secret"), true);
        strict_1.default.equal(email_1.__private__.isValidUnsubscribeRequest(uid, emailType, ts, `${sig}tampered`, nowMs + 1_000, "test-unsubscribe-secret"), false);
    }
    finally {
        if (previousSecret === undefined) {
            delete process.env.UNSUBSCRIBE_HMAC_SECRET;
        }
        else {
            process.env.UNSUBSCRIBE_HMAC_SECRET = previousSecret;
        }
    }
});
(0, node_test_1.default)("unsubscribe link token cannot be used for another user", () => {
    const previousSecret = process.env.UNSUBSCRIBE_HMAC_SECRET;
    process.env.UNSUBSCRIBE_HMAC_SECRET = "test-unsubscribe-secret";
    try {
        const nowMs = 1_725_000_000_000;
        const urlString = email_1.__private__.buildWeeklyDigestUnsubscribeURL("testUser123", nowMs);
        strict_1.default.ok(urlString);
        const parsed = new URL(urlString);
        const emailType = parsed.searchParams.get("type");
        const ts = parsed.searchParams.get("ts");
        const sig = parsed.searchParams.get("sig");
        strict_1.default.equal(email_1.__private__.isValidUnsubscribeRequest("differentUser456", emailType, ts, sig, nowMs + 1_000, "test-unsubscribe-secret"), false);
    }
    finally {
        if (previousSecret === undefined) {
            delete process.env.UNSUBSCRIBE_HMAC_SECRET;
        }
        else {
            process.env.UNSUBSCRIBE_HMAC_SECRET = previousSecret;
        }
    }
});
(0, node_test_1.default)("unsubscribe get renders confirmation not executes", () => {
    const html = email_1.__private__.renderWeeklyDigestUnsubscribeConfirmation("testUser123", email_1.__private__.WEEKLY_DIGEST_EMAIL_TYPE, "1725000000000", "signature");
    strict_1.default.match(html, /<form method="POST">/);
    strict_1.default.match(html, /Confirm unsubscribe/);
    strict_1.default.doesNotMatch(html, /You will no longer receive weekly digest emails/);
});
(0, node_test_1.default)("digest not sent twice in same week", () => {
    const firstWindow = email_1.__private__.weeklyDigestWindowKey(new Date("2026-03-16T09:00:00.000Z"));
    const secondWindow = email_1.__private__.weeklyDigestWindowKey(new Date("2026-03-18T12:00:00.000Z"));
    strict_1.default.equal(firstWindow, secondWindow);
    strict_1.default.equal(email_1.__private__.weeklyDigestIdempotencyKey("user_123", firstWindow), email_1.__private__.weeklyDigestIdempotencyKey("user_123", secondWindow));
    strict_1.default.equal(email_1.__private__.digestReservationAction("sent"), "skip");
    strict_1.default.equal(email_1.__private__.digestReservationAction("reserved"), "skip");
});
(0, node_test_1.default)("digest retry succeeds when previous send failed", () => {
    strict_1.default.equal(email_1.__private__.digestReservationAction("failed"), "reserve");
    strict_1.default.equal(email_1.__private__.digestReservationAction(null), "reserve");
});
(0, node_test_1.default)("log output does not contain raw email or domain", () => {
    const previousKey = process.env.LOG_PSEUDONYMIZATION_KEY;
    process.env.LOG_PSEUDONYMIZATION_KEY = "test-log-key";
    try {
        const skipContext = email_1.__private__.buildEmailTransportSkipLogContext({
            to: "student@example.com",
            from: "noreply@arrivaluk.app",
            subject: "Sensitive subject",
            html: "<p>Hello</p>",
        });
        const failureContext = email_1.__private__.buildEmailFailureLogContext("boom", {
            userId: "user_123",
            ticketId: "ticket_456",
            templateKey: "support_followup",
        });
        const serialized = JSON.stringify({
            ...skipContext,
            ...failureContext,
        });
        strict_1.default.equal(serialized.includes("student@example.com"), false);
        strict_1.default.equal(serialized.includes("example.com"), false);
        strict_1.default.equal(serialized.includes("user_123"), false);
        strict_1.default.equal(serialized.includes("ticket_456"), false);
        strict_1.default.match(serialized, /uid:[0-9a-f]{12}/);
        strict_1.default.match(serialized, /ticket:[0-9a-f]{12}/);
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
//# sourceMappingURL=email.test.js.map