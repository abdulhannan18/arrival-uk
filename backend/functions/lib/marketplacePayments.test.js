"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const marketplacePayments_1 = require("./marketplacePayments");
(0, node_test_1.default)("parseConfirmRequest rejects malformed marketplace confirmation payloads", () => {
    strict_1.default.equal(marketplacePayments_1.__private__.parseConfirmRequest(null), null);
    strict_1.default.equal(marketplacePayments_1.__private__.parseConfirmRequest({}), null);
    strict_1.default.equal(marketplacePayments_1.__private__.parseConfirmRequest({
        providerID: "bank_provider",
        userID: "user_123",
        paymentMode: "none",
        transactionReference: "storekit-123",
        paymentPayload: "123",
        requestedAt: "2026-03-20T12:00:00.000Z",
    }), null);
});
(0, node_test_1.default)("buildConfirmationKey is stable for the same user provider and transaction", () => {
    const first = marketplacePayments_1.__private__.buildConfirmationKey("user_123", "bank_provider", "storekit-123");
    const second = marketplacePayments_1.__private__.buildConfirmationKey("user_123", "bank_provider", "storekit-123");
    const third = marketplacePayments_1.__private__.buildConfirmationKey("user_124", "bank_provider", "storekit-123");
    strict_1.default.equal(first, second);
    strict_1.default.notEqual(first, third);
});
(0, node_test_1.default)("storekit confirmation accepts verified transaction references", () => {
    const confirmation = marketplacePayments_1.__private__.confirmAuthorizedPayment({
        providerID: "bank_provider",
        userID: "user_123",
        paymentMode: "storekit",
        transactionReference: "storekit-987654321",
        paymentPayload: "987654321",
        requestedAt: "2026-03-20T12:00:00.000Z",
    }, 1_742_473_600_000);
    strict_1.default.equal(confirmation.confirmed, true);
    strict_1.default.equal(confirmation.receipt, "storekit-987654321");
    strict_1.default.equal(confirmation.grantedAtMillis, 1_742_473_600_000);
});
(0, node_test_1.default)("apple pay confirmation is rejected until a processor is configured", () => {
    const confirmation = marketplacePayments_1.__private__.confirmAuthorizedPayment({
        providerID: "bank_provider",
        userID: "user_123",
        paymentMode: "apple_pay",
        transactionReference: "applepay-token",
        paymentPayload: "opaque-token",
        requestedAt: "2026-03-20T12:00:00.000Z",
    });
    strict_1.default.equal(confirmation.confirmed, false);
    strict_1.default.equal(confirmation.errorMessage, "apple_pay_processor_unconfigured");
});
(0, node_test_1.default)("invalid storekit payloads are rejected", () => {
    const confirmation = marketplacePayments_1.__private__.confirmAuthorizedPayment({
        providerID: "bank_provider",
        userID: "user_123",
        paymentMode: "storekit",
        transactionReference: "storekit-",
        paymentPayload: "",
        requestedAt: "2026-03-20T12:00:00.000Z",
    });
    strict_1.default.equal(confirmation.confirmed, false);
    strict_1.default.equal(confirmation.errorMessage, "invalid_storekit_receipt");
});
//# sourceMappingURL=marketplacePayments.test.js.map