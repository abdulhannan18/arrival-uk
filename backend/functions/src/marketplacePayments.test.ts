import assert from "node:assert/strict";
import test from "node:test";
import { __private__ } from "./marketplacePayments";

test("parseConfirmRequest rejects malformed marketplace confirmation payloads", () => {
  assert.equal(__private__.parseConfirmRequest(null), null);
  assert.equal(__private__.parseConfirmRequest({}), null);
  assert.equal(__private__.parseConfirmRequest({
    providerID: "bank_provider",
    userID: "user_123",
    paymentMode: "none",
    transactionReference: "storekit-123",
    paymentPayload: "123",
    requestedAt: "2026-03-20T12:00:00.000Z",
  }), null);
});

test("buildConfirmationKey is stable for the same user provider and transaction", () => {
  const first = __private__.buildConfirmationKey("user_123", "bank_provider", "storekit-123");
  const second = __private__.buildConfirmationKey("user_123", "bank_provider", "storekit-123");
  const third = __private__.buildConfirmationKey("user_124", "bank_provider", "storekit-123");

  assert.equal(first, second);
  assert.notEqual(first, third);
});

test("storekit confirmation accepts verified transaction references", () => {
  const confirmation = __private__.confirmAuthorizedPayment({
    providerID: "bank_provider",
    userID: "user_123",
    paymentMode: "storekit",
    transactionReference: "storekit-987654321",
    paymentPayload: "987654321",
    requestedAt: "2026-03-20T12:00:00.000Z",
  }, 1_742_473_600_000);

  assert.equal(confirmation.confirmed, true);
  assert.equal(confirmation.receipt, "storekit-987654321");
  assert.equal(confirmation.grantedAtMillis, 1_742_473_600_000);
});

test("apple pay confirmation is rejected until a processor is configured", () => {
  const confirmation = __private__.confirmAuthorizedPayment({
    providerID: "bank_provider",
    userID: "user_123",
    paymentMode: "apple_pay",
    transactionReference: "applepay-token",
    paymentPayload: "opaque-token",
    requestedAt: "2026-03-20T12:00:00.000Z",
  });

  assert.equal(confirmation.confirmed, false);
  assert.equal(confirmation.errorMessage, "apple_pay_processor_unconfigured");
});

test("invalid storekit payloads are rejected", () => {
  const confirmation = __private__.confirmAuthorizedPayment({
    providerID: "bank_provider",
    userID: "user_123",
    paymentMode: "storekit",
    transactionReference: "storekit-",
    paymentPayload: "",
    requestedAt: "2026-03-20T12:00:00.000Z",
  });

  assert.equal(confirmation.confirmed, false);
  assert.equal(confirmation.errorMessage, "invalid_storekit_receipt");
});
