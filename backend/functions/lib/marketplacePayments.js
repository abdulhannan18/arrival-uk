"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.__private__ = exports.marketplacePaymentConfirm = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const crypto_1 = require("crypto");
const constants_1 = require("./constants");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const MAX_STRING_LENGTH = 256;
/*
 HTTP contract: POST /v1/marketplace/payments/confirm
 Request body: { providerID, userID, paymentMode, transactionReference, paymentPayload, requestedAt }
 Success body: { confirmed, receipt?, grantedAtMillis?, errorMessage? }
 Idempotency contract: the same { userID, providerID, transactionReference } tuple returns the cached response.
 Current processor coverage:
 - storekit: accepts server recording only for transaction references produced by a locally verified StoreKit
   purchase and grants the entitlement idempotently.
 - apple_pay: rejected until a backend payment processor is configured for token settlement.
 */
function isRecord(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function safeString(value) {
    if (typeof value !== "string")
        return "";
    return value.trim().slice(0, MAX_STRING_LENGTH);
}
function safeISODate(value) {
    if (typeof value !== "string")
        return new Date(0).toISOString();
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime()))
        return new Date(0).toISOString();
    return parsed.toISOString();
}
function normalizedPaymentMode(value) {
    const normalized = safeString(value).toLowerCase();
    switch (normalized) {
        case "storekit":
            return "storekit";
        case "apple_pay":
            return "apple_pay";
        case "none":
            return "none";
        default:
            return null;
    }
}
function parseConfirmRequest(value) {
    if (!isRecord(value))
        return null;
    const providerID = safeString(value.providerID).toLowerCase();
    const userID = safeString(value.userID);
    const transactionReference = safeString(value.transactionReference);
    const paymentPayload = safeString(value.paymentPayload);
    const paymentMode = normalizedPaymentMode(value.paymentMode);
    if (!providerID || !userID || !transactionReference || !paymentPayload || !paymentMode || paymentMode === "none") {
        return null;
    }
    return {
        providerID,
        userID,
        paymentMode,
        transactionReference,
        paymentPayload,
        requestedAt: safeISODate(value.requestedAt),
    };
}
function buildConfirmationKey(userID, providerID, transactionReference) {
    return (0, crypto_1.createHash)("sha256")
        .update(`${userID}:${providerID}:${transactionReference}`)
        .digest("hex");
}
function confirmationCollectionRef() {
    return db.collection(constants_1.Collections.ops.root)
        .doc(constants_1.Collections.ops.marketplacePayments)
        .collection(constants_1.Collections.ops.items);
}
function confirmAuthorizedPayment(request, nowMillis = Date.now()) {
    if (request.paymentMode === "apple_pay") {
        return {
            confirmed: false,
            errorMessage: "apple_pay_processor_unconfigured",
        };
    }
    if (request.paymentMode !== "storekit") {
        return {
            confirmed: false,
            errorMessage: "unsupported_payment_mode",
        };
    }
    if (!request.transactionReference.startsWith("storekit-")) {
        return {
            confirmed: false,
            errorMessage: "invalid_storekit_transaction_reference",
        };
    }
    const normalizedPayload = request.paymentPayload.trim();
    const normalizedReference = request.transactionReference.replace(/^storekit-/, "").trim();
    const isValidReference = /^[0-9A-Za-z._-]+$/.test(normalizedReference);
    if (!normalizedPayload || !normalizedReference || !isValidReference) {
        return {
            confirmed: false,
            errorMessage: "invalid_storekit_receipt",
        };
    }
    return {
        confirmed: true,
        receipt: request.transactionReference,
        grantedAtMillis: nowMillis,
    };
}
exports.marketplacePaymentConfirm = functions.https.onRequest(async (request, response) => {
    if (request.method !== "POST") {
        response.set("Allow", "POST");
        response.status(405).json({ error: "method_not_allowed" });
        return;
    }
    const parsedRequest = parseConfirmRequest(request.body);
    if (!parsedRequest) {
        response.status(400).json({ error: "invalid_marketplace_payment_confirmation_request" });
        return;
    }
    const idempotencyKey = buildConfirmationKey(parsedRequest.userID, parsedRequest.providerID, parsedRequest.transactionReference);
    const recordRef = confirmationCollectionRef().doc(idempotencyKey);
    try {
        const existingRecord = await recordRef.get();
        if (existingRecord.exists) {
            const data = existingRecord.data();
            if (data?.response) {
                response.status(200).json(data.response);
                return;
            }
        }
        const confirmation = confirmAuthorizedPayment(parsedRequest);
        const storedRecord = {
            idempotencyKey,
            request: parsedRequest,
            response: confirmation,
            createdAt: new Date().toISOString(),
        };
        await recordRef.set(storedRecord);
        response.status(200).json(confirmation);
    }
    catch (error) {
        functions.logger.error("marketplace_payment_confirmation_unavailable", {
            error: error instanceof Error ? error.message : "unknown_error",
        });
        response.status(503).json({ error: "marketplace_payment_confirmation_unavailable" });
    }
});
exports.__private__ = {
    normalizedPaymentMode,
    parseConfirmRequest,
    buildConfirmationKey,
    confirmAuthorizedPayment,
};
//# sourceMappingURL=marketplacePayments.js.map