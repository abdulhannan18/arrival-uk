import assert from "node:assert/strict";
import test from "node:test";
import { pseudonymizeLogIdentifier } from "./logPrivacy";

test("pseudonymizeLogIdentifier hashes identifiers without exposing raw value", () => {
  const previous = process.env.LOG_PSEUDONYMIZATION_KEY;
  process.env.LOG_PSEUDONYMIZATION_KEY = "shared-log-test-key";

  try {
    const pseudonymized = pseudonymizeLogIdentifier("uid", "user-123");

    assert.equal(typeof pseudonymized, "string");
    assert.equal(String(pseudonymized).includes("user-123"), false);
    assert.match(String(pseudonymized), /^uid:[0-9a-f]{12}$/);
    assert.equal(
      pseudonymizeLogIdentifier("uid", "user-123"),
      pseudonymized
    );
  } finally {
    if (previous === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previous;
    }
  }
});

test("pseudonymizeLogIdentifier requires a configured key", () => {
  const previous = process.env.LOG_PSEUDONYMIZATION_KEY;
  delete process.env.LOG_PSEUDONYMIZATION_KEY;

  try {
    assert.equal(pseudonymizeLogIdentifier("uid", "user-123"), undefined);
  } finally {
    if (previous === undefined) {
      delete process.env.LOG_PSEUDONYMIZATION_KEY;
    } else {
      process.env.LOG_PSEUDONYMIZATION_KEY = previous;
    }
  }
});
