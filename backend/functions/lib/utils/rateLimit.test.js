"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const rateLimit_1 = require("./rateLimit");
(0, node_test_1.default)("computeNextWindowState starts a fresh window when no prior state exists", () => {
    const nowMs = 1_700_000_000_000;
    const result = rateLimit_1.__private__.computeNextWindowState(undefined, nowMs, 60_000);
    strict_1.default.equal(result.windowStartMs, nowMs);
    strict_1.default.equal(result.count, 1);
});
(0, node_test_1.default)("computeNextWindowState increments within the same window", () => {
    const nowMs = 1_700_000_010_000;
    const previous = { windowStartMs: 1_700_000_000_000, count: 4 };
    const result = rateLimit_1.__private__.computeNextWindowState(previous, nowMs, 60_000);
    strict_1.default.equal(result.windowStartMs, previous.windowStartMs);
    strict_1.default.equal(result.count, 5);
});
(0, node_test_1.default)("computeNextWindowState resets after window expires", () => {
    const previous = { windowStartMs: 1_700_000_000_000, count: 9 };
    const nowMs = previous.windowStartMs + 120_000;
    const result = rateLimit_1.__private__.computeNextWindowState(previous, nowMs, 60_000);
    strict_1.default.equal(result.windowStartMs, nowMs);
    strict_1.default.equal(result.count, 1);
});
(0, node_test_1.default)("computeNextWindowState tolerates malformed stored values", () => {
    const nowMs = 1_700_000_000_000;
    const previous = { windowStartMs: Number.NaN, count: -4 };
    const result = rateLimit_1.__private__.computeNextWindowState(previous, nowMs, 60_000);
    strict_1.default.equal(result.windowStartMs, nowMs);
    strict_1.default.equal(result.count, 1);
});
(0, node_test_1.default)("shouldRetryTransactionError returns true for retryable firestore errors", () => {
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError({ code: 10 }), true);
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError({ code: 14 }), true);
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError({ code: "aborted" }), true);
});
(0, node_test_1.default)("shouldRetryTransactionError returns false for non-retryable errors", () => {
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError({ code: 7 }), false);
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError({ code: "permission-denied" }), false);
    strict_1.default.equal(rateLimit_1.__private__.shouldRetryTransactionError(new Error("boom")), false);
});
//# sourceMappingURL=rateLimit.test.js.map