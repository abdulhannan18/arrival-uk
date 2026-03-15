import test from "node:test";
import assert from "node:assert/strict";
import * as functions from "firebase-functions";
import { assertCallableAppCheck, __private__ } from "./appCheck";

test("parseBooleanFlag accepts truthy string variants", () => {
  assert.equal(__private__.parseBooleanFlag("true"), true);
  assert.equal(__private__.parseBooleanFlag("1"), true);
  assert.equal(__private__.parseBooleanFlag("yes"), true);
  assert.equal(__private__.parseBooleanFlag("on"), true);
});

test("parseBooleanFlag rejects non-truthy values", () => {
  assert.equal(__private__.parseBooleanFlag("false"), false);
  assert.equal(__private__.parseBooleanFlag("0"), false);
  assert.equal(__private__.parseBooleanFlag(undefined), false);
});

test("assertCallableAppCheck allows emulators", () => {
  assert.doesNotThrow(() =>
    assertCallableAppCheck(
      { app: undefined, auth: undefined },
      "trackLogin",
      { isEmulator: true, allowUnverified: false }
    )
  );
});

test("assertCallableAppCheck allows explicitly unverified mode", () => {
  assert.doesNotThrow(() =>
    assertCallableAppCheck(
      { app: undefined, auth: undefined },
      "trackLogin",
      { isEmulator: false, allowUnverified: true }
    )
  );
});

test("assertCallableAppCheck rejects missing app attestation in production mode", () => {
  assert.throws(
    () =>
      assertCallableAppCheck(
        { app: undefined, auth: { uid: "user_123" } as never },
        "trackLogin",
        { isEmulator: false, allowUnverified: false }
      ),
    (error: unknown) => {
      if (!(error instanceof functions.https.HttpsError)) return false;
      return error.code === "failed-precondition";
    }
  );
});

test("assertCallableAppCheck passes when app check payload exists", () => {
  assert.doesNotThrow(() =>
    assertCallableAppCheck(
      {
        app: { appId: "1:1234567890:ios:test", token: {} } as never,
        auth: undefined,
      },
      "trackLogin",
      { isEmulator: false, allowUnverified: false }
    )
  );
});

test("isUnsafeBypassConfiguration flags non-emulator bypass in production-like runtime", () => {
  assert.equal(
    __private__.isUnsafeBypassConfiguration({
      isEmulator: false,
      allowUnverified: true,
      nodeEnv: "production",
    }),
    true
  );
  assert.equal(
    __private__.isUnsafeBypassConfiguration({
      isEmulator: true,
      allowUnverified: true,
      nodeEnv: "development",
    }),
    false
  );
});

test("assertSafeBypassConfiguration throws when bypass is enabled outside emulator", () => {
  assert.throws(
    () =>
      __private__.assertSafeBypassConfiguration({
        isEmulator: false,
        allowUnverified: true,
        nodeEnv: "development",
      })
  );
});
