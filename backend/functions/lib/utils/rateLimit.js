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
exports.__private__ = void 0;
exports.enforceRateLimit = enforceRateLimit;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const RETRYABLE_TRANSACTION_CODES = new Set([
    4, // DEADLINE_EXCEEDED
    10, // ABORTED
    14, // UNAVAILABLE
    "aborted",
    "deadline-exceeded",
    "unavailable",
]);
function normalizedNumber(value, fallback) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric))
        return fallback;
    if (numeric < 0)
        return fallback;
    return numeric;
}
function computeNextWindowState(previous, nowMs, windowMs) {
    const previousWindowStart = normalizedNumber(previous?.windowStartMs, 0);
    const previousCount = normalizedNumber(previous?.count, 0);
    const windowStillOpen = previousWindowStart > 0 && (nowMs - previousWindowStart) < windowMs;
    return {
        windowStartMs: windowStillOpen ? previousWindowStart : nowMs,
        count: windowStillOpen ? previousCount + 1 : 1,
    };
}
function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
function shouldRetryTransactionError(error) {
    const code = error?.code;
    if (typeof code === "number" || typeof code === "string") {
        return RETRYABLE_TRANSACTION_CODES.has(code);
    }
    return false;
}
async function enforceRateLimit(options) {
    const nowMs = options.nowMs ?? Date.now();
    const ref = options.db.collection("rateLimits").doc(`${options.namespace}_${options.userId}`);
    const maxAttempts = 4;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        try {
            await options.db.runTransaction(async (transaction) => {
                const snapshot = await transaction.get(ref);
                const current = snapshot.data();
                const next = computeNextWindowState(current, nowMs, options.windowMs);
                if (next.count > options.maxRequests) {
                    throw new functions.https.HttpsError("resource-exhausted", options.errorMessage ?? "Rate limit exceeded.");
                }
                transaction.set(ref, {
                    count: next.count,
                    windowStartMs: next.windowStartMs,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            });
            return;
        }
        catch (error) {
            if (!shouldRetryTransactionError(error) || attempt == maxAttempts) {
                throw error;
            }
            const backoffMs = 50 * (2 ** (attempt - 1));
            await wait(backoffMs);
        }
    }
}
exports.__private__ = {
    computeNextWindowState,
    shouldRetryTransactionError,
};
//# sourceMappingURL=rateLimit.js.map