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
        const ts = parsed.searchParams.get("ts");
        const sig = parsed.searchParams.get("sig");
        strict_1.default.equal(uid, userId);
        strict_1.default.equal(ts, String(nowMs));
        strict_1.default.ok(sig);
        strict_1.default.equal(email_1.__private__.isValidUnsubscribeRequest(uid, ts, sig, nowMs + 1_000, "test-unsubscribe-secret"), true);
        strict_1.default.equal(email_1.__private__.isValidUnsubscribeRequest(uid, ts, `${sig}tampered`, nowMs + 1_000, "test-unsubscribe-secret"), false);
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
//# sourceMappingURL=email.test.js.map