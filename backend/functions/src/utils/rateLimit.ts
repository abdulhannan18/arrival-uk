import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

type RateLimitState = {
  count: number;
  windowStartMs: number;
};

type EnforceRateLimitOptions = {
  db: FirebaseFirestore.Firestore;
  namespace: string;
  userId: string;
  maxRequests: number;
  windowMs: number;
  nowMs?: number;
  errorMessage?: string;
};

const RETRYABLE_TRANSACTION_CODES = new Set<number | string>([
  4, // DEADLINE_EXCEEDED
  10, // ABORTED
  14, // UNAVAILABLE
  "aborted",
  "deadline-exceeded",
  "unavailable",
]);

function normalizedNumber(value: unknown, fallback: number): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  if (numeric < 0) return fallback;
  return numeric;
}

function computeNextWindowState(
  previous: Partial<RateLimitState> | undefined,
  nowMs: number,
  windowMs: number
): RateLimitState {
  const previousWindowStart = normalizedNumber(previous?.windowStartMs, 0);
  const previousCount = normalizedNumber(previous?.count, 0);
  const windowStillOpen = previousWindowStart > 0 && (nowMs - previousWindowStart) < windowMs;

  return {
    windowStartMs: windowStillOpen ? previousWindowStart : nowMs,
    count: windowStillOpen ? previousCount + 1 : 1,
  };
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function shouldRetryTransactionError(error: unknown): boolean {
  const code = (error as { code?: unknown })?.code;
  if (typeof code === "number" || typeof code === "string") {
    return RETRYABLE_TRANSACTION_CODES.has(code);
  }
  return false;
}

export async function enforceRateLimit(options: EnforceRateLimitOptions): Promise<void> {
  const nowMs = options.nowMs ?? Date.now();
  const ref = options.db.collection("rateLimits").doc(`${options.namespace}_${options.userId}`);
  const maxAttempts = 4;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await options.db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const current = snapshot.data() as Partial<RateLimitState> | undefined;
        const next = computeNextWindowState(current, nowMs, options.windowMs);

        if (next.count > options.maxRequests) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            options.errorMessage ?? "Rate limit exceeded."
          );
        }

        transaction.set(
          ref,
          {
            count: next.count,
            windowStartMs: next.windowStartMs,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      return;
    } catch (error) {
      if (!shouldRetryTransactionError(error) || attempt == maxAttempts) {
        throw error;
      }

      const backoffMs = 50 * (2 ** (attempt - 1));
      await wait(backoffMs);
    }
  }
}

export const __private__ = {
  computeNextWindowState,
  shouldRetryTransactionError,
};
