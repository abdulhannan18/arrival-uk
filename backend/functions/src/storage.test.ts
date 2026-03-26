import test from "node:test";
import assert from "node:assert/strict";
import { __private__ } from "./storage";

test("pseudonymizeLogIdentifier does not contain raw storage identifiers", () => {
  const previous = process.env.LOG_PSEUDONYMIZATION_KEY;
  process.env.LOG_PSEUDONYMIZATION_KEY = "storage-log-test-key";

  try {
    const userRef = __private__.pseudonymizeLogIdentifier("uid", "user-123");
    const fileRef = __private__.pseudonymizeLogIdentifier("file", "users/user-123/profile/avatar.png");

    assert.ok(userRef?.startsWith("uid:"));
    assert.ok(fileRef?.startsWith("file:"));
    assert.ok(!userRef?.includes("user-123"));
    assert.ok(!fileRef?.includes("user-123"));
    assert.ok(!fileRef?.includes("avatar.png"));
  } finally {
    if (previous === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previous;
    }
  }
});

test("pseudonymizeLogIdentifier requires a configured pseudonymization key", () => {
  const previous = process.env.LOG_PSEUDONYMIZATION_KEY;
  delete process.env.LOG_PSEUDONYMIZATION_KEY;

  try {
    const userRef = __private__.pseudonymizeLogIdentifier("uid", "user-123");
    assert.equal(userRef, undefined);
  } finally {
    if (previous === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previous;
    }
  }
});
