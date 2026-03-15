import test from "node:test";
import assert from "node:assert/strict";
import { __private__ } from "./auth";

test("generateReferralCode returns expected shape", () => {
  const code = __private__.generateReferralCode();
  assert.match(code, /^[0-9A-F]{12}$/);
});

test("generateReferralCode has high uniqueness across samples", () => {
  const samples = new Set<string>();
  for (let index = 0; index < 512; index += 1) {
    samples.add(__private__.generateReferralCode());
  }

  // Random collisions are possible but should remain rare in this sample size.
  assert.ok(samples.size > 500);
});

test("normalizedPlatform only accepts allowlisted values", () => {
  assert.equal(__private__.normalizedPlatform("ios"), "ios");
  assert.equal(__private__.normalizedPlatform("ANDROID"), "android");
  assert.equal(__private__.normalizedPlatform("desktop"), "unknown");
  assert.equal(__private__.normalizedPlatform(undefined), "unknown");
});

test("normalizedAppVersion enforces expected format", () => {
  assert.equal(__private__.normalizedAppVersion("1.2.3"), "1.2.3");
  assert.equal(__private__.normalizedAppVersion(" 2_0-rc1 "), "2_0-rc1");
  assert.equal(__private__.normalizedAppVersion("1.0 beta"), "unknown");
  assert.equal(__private__.normalizedAppVersion(undefined), "unknown");
});

test("sanitizeAnalyticsEventType enforces non-empty and max length", () => {
  assert.equal(__private__.sanitizeAnalyticsEventType(" home_opened "), "home_opened");
  assert.equal(__private__.sanitizeAnalyticsEventType(""), null);
  assert.equal(__private__.sanitizeAnalyticsEventType(undefined), null);
  assert.equal(
    __private__.sanitizeAnalyticsEventType("x".repeat(80))?.length,
    64
  );
});

test("sanitizeAnalyticsProperties keeps only supported primitive values", () => {
  const sanitized = __private__.sanitizeAnalyticsProperties({
    validString: "value",
    validBool: true,
    validNumber: 42,
    nested: { nope: true },
    list: [1, 2, 3],
    nil: null,
  });

  assert.deepEqual(sanitized, {
    validString: "value",
    validBool: true,
    validNumber: 42,
  });
});
