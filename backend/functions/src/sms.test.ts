import assert from "node:assert/strict";
import test from "node:test";
import * as functions from "firebase-functions";
import { __private__ } from "./sms";

test("isValidE164Phone validates E.164 format", () => {
  assert.equal(__private__.isValidE164Phone("+447911123456"), true);
  assert.equal(__private__.isValidE164Phone("07911123456"), false);
  assert.equal(__private__.isValidE164Phone("+1"), false);
});

test("sendSMSReminderImpl rejects invalid E.164 phone numbers", async () => {
  await assert.rejects(
    __private__.sendSMSReminderImpl(
      { phoneNumber: "07911123456", message: "Hello" },
      { auth: { uid: "user_1" } } as unknown as functions.https.CallableContext,
      {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => undefined,
        getTwilioClient: () => ({
          messages: {
            create: async () => ({ sid: "sid_1" }),
          },
        }),
        fromPhone: () => "+447000000001",
      }
    ),
    (error: unknown) => {
      const typed = error as functions.https.HttpsError;
      return typed.code === "invalid-argument";
    }
  );
});

test("redactPhone keeps only final 4 digits", () => {
  assert.equal(__private__.redactPhone("+447911123456"), "***3456");
  assert.equal(__private__.redactPhone("+1234"), "***");
});

test("sendSMSReminderImpl returns failed-precondition when Twilio is not configured", async () => {
  await assert.rejects(
    __private__.sendSMSReminderImpl(
      { phoneNumber: "+447911123456", message: "Hello" },
      { auth: { uid: "user_2" } } as unknown as functions.https.CallableContext,
      {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => undefined,
        getTwilioClient: () => null,
        fromPhone: () => null,
      }
    ),
    (error: unknown) => {
      const typed = error as functions.https.HttpsError;
      return typed.code === "failed-precondition";
    }
  );
});

test("sendSMSReminderImpl propagates rate-limit failures", async () => {
  await assert.rejects(
    __private__.sendSMSReminderImpl(
      { phoneNumber: "+447911123456", message: "Hello" },
      { auth: { uid: "user_3" } } as unknown as functions.https.CallableContext,
      {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "Rate limit exceeded for SMS sending."
          );
        },
        getTwilioClient: () => ({
          messages: {
            create: async () => ({ sid: "sid_2" }),
          },
        }),
        fromPhone: () => "+447000000002",
      }
    ),
    (error: unknown) => {
      const typed = error as functions.https.HttpsError;
      return typed.code === "resource-exhausted";
    }
  );
});
