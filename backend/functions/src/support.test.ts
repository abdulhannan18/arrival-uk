import test from "node:test";
import assert from "node:assert/strict";
import * as functions from "firebase-functions";
import { __private__ } from "./support";

test("normalizedPlatform accepts allowlisted values only", () => {
  assert.equal(__private__.normalizedPlatform("IOS"), "ios");
  assert.equal(__private__.normalizedPlatform("android"), "android");
  assert.equal(__private__.normalizedPlatform("desktop"), "unknown");
});

test("normalizedAppVersion enforces safe version format", () => {
  assert.equal(__private__.normalizedAppVersion("1.2.3"), "1.2.3");
  assert.equal(__private__.normalizedAppVersion(" 2_0-rc1 "), "2_0-rc1");
  assert.equal(__private__.normalizedAppVersion("bad version"), "unknown");
});

test("sanitizeSupportMetadata keeps only primitive values and caps entries", () => {
  const input: Record<string, unknown> = {};
  for (let index = 0; index < 30; index += 1) {
    input[`k${index}`] = index;
  }
  input.arrayValue = [1, 2, 3];
  input.objectValue = { nested: true };
  input.booleanValue = true;
  input.stringValue = "hello";

  const sanitized = __private__.sanitizeSupportMetadata(input)!;
  assert.ok(sanitized);
  assert.ok(Object.keys(sanitized).length <= 20);
  assert.equal(sanitized.arrayValue, undefined);
  assert.equal(sanitized.objectValue, undefined);
});

test("validateTicketID rejects invalid identifiers", () => {
  assert.equal(__private__.validateTicketID("abc123"), "abc123");

  assert.throws(
    () => __private__.validateTicketID("bad/id"),
    (error: unknown) => {
      if (!(error instanceof functions.https.HttpsError)) return false;
      return error.code === "invalid-argument";
    }
  );

  assert.throws(
    () => __private__.validateTicketID(""),
    (error: unknown) => {
      if (!(error instanceof functions.https.HttpsError)) return false;
      return error.code === "invalid-argument";
    }
  );
});
