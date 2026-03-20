import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { createHash } from "crypto";
import { Collections } from "./constants";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const MAX_STRING_LENGTH = 256;

type MarketplacePaymentMode = "storekit" | "apple_pay" | "none";

type MarketplacePaymentConfirmationRequest = {
  providerID: string;
  userID: string;
  paymentMode: MarketplacePaymentMode;
  transactionReference: string;
  paymentPayload: string;
  requestedAt: string;
};

type MarketplacePaymentConfirmationResponse = {
  confirmed: boolean;
  receipt?: string;
  grantedAtMillis?: number;
  errorMessage?: string;
};

type StoredMarketplacePaymentRecord = {
  idempotencyKey: string;
  request: MarketplacePaymentConfirmationRequest;
  response: MarketplacePaymentConfirmationResponse;
  createdAt: string;
};

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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function safeString(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, MAX_STRING_LENGTH);
}

function safeISODate(value: unknown): string {
  if (typeof value !== "string") return new Date(0).toISOString();
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return new Date(0).toISOString();
  return parsed.toISOString();
}

function normalizedPaymentMode(value: unknown): MarketplacePaymentMode | null {
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

function parseConfirmRequest(value: unknown): MarketplacePaymentConfirmationRequest | null {
  if (!isRecord(value)) return null;

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

function buildConfirmationKey(
  userID: string,
  providerID: string,
  transactionReference: string
): string {
  return createHash("sha256")
    .update(`${userID}:${providerID}:${transactionReference}`)
    .digest("hex");
}

function confirmationCollectionRef(): FirebaseFirestore.CollectionReference {
  return db.collection(Collections.ops.root)
    .doc(Collections.ops.marketplacePayments)
    .collection(Collections.ops.items);
}

function confirmAuthorizedPayment(
  request: MarketplacePaymentConfirmationRequest,
  nowMillis = Date.now()
): MarketplacePaymentConfirmationResponse {
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

export const marketplacePaymentConfirm = functions.https.onRequest(async (request, response) => {
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

  const idempotencyKey = buildConfirmationKey(
    parsedRequest.userID,
    parsedRequest.providerID,
    parsedRequest.transactionReference
  );
  const recordRef = confirmationCollectionRef().doc(idempotencyKey);

  try {
    const existingRecord = await recordRef.get();
    if (existingRecord.exists) {
      const data = existingRecord.data() as StoredMarketplacePaymentRecord | undefined;
      if (data?.response) {
        response.status(200).json(data.response);
        return;
      }
    }

    const confirmation = confirmAuthorizedPayment(parsedRequest);
    const storedRecord: StoredMarketplacePaymentRecord = {
      idempotencyKey,
      request: parsedRequest,
      response: confirmation,
      createdAt: new Date().toISOString(),
    };
    await recordRef.set(storedRecord);

    response.status(200).json(confirmation);
  } catch (error) {
    functions.logger.error("marketplace_payment_confirmation_unavailable", {
      error: error instanceof Error ? error.message : "unknown_error",
    });
    response.status(503).json({ error: "marketplace_payment_confirmation_unavailable" });
  }
});

export const __private__ = {
  normalizedPaymentMode,
  parseConfirmRequest,
  buildConfirmationKey,
  confirmAuthorizedPayment,
};
