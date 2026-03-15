import test from "node:test";
import assert from "node:assert/strict";
import { __private__ } from "./rateLimit";

test("computeNextWindowState starts a fresh window when no prior state exists", () => {
  const nowMs = 1_700_000_000_000;
  const result = __private__.computeNextWindowState(undefined, nowMs, 60_000);

  assert.equal(result.windowStartMs, nowMs);
  assert.equal(result.count, 1);
});

test("computeNextWindowState increments within the same window", () => {
  const nowMs = 1_700_000_010_000;
  const previous = { windowStartMs: 1_700_000_000_000, count: 4 };
  const result = __private__.computeNextWindowState(previous, nowMs, 60_000);

  assert.equal(result.windowStartMs, previous.windowStartMs);
  assert.equal(result.count, 5);
});

test("computeNextWindowState resets after window expires", () => {
  const previous = { windowStartMs: 1_700_000_000_000, count: 9 };
  const nowMs = previous.windowStartMs + 120_000;
  const result = __private__.computeNextWindowState(previous, nowMs, 60_000);

  assert.equal(result.windowStartMs, nowMs);
  assert.equal(result.count, 1);
});

test("computeNextWindowState tolerates malformed stored values", () => {
  const nowMs = 1_700_000_000_000;
  const previous = { windowStartMs: Number.NaN, count: -4 };
  const result = __private__.computeNextWindowState(previous, nowMs, 60_000);

  assert.equal(result.windowStartMs, nowMs);
  assert.equal(result.count, 1);
});

test("shouldRetryTransactionError returns true for retryable firestore errors", () => {
  assert.equal(__private__.shouldRetryTransactionError({ code: 10 }), true);
  assert.equal(__private__.shouldRetryTransactionError({ code: 14 }), true);
  assert.equal(__private__.shouldRetryTransactionError({ code: "aborted" }), true);
});

test("shouldRetryTransactionError returns false for non-retryable errors", () => {
  assert.equal(__private__.shouldRetryTransactionError({ code: 7 }), false);
  assert.equal(__private__.shouldRetryTransactionError({ code: "permission-denied" }), false);
  assert.equal(__private__.shouldRetryTransactionError(new Error("boom")), false);
});
