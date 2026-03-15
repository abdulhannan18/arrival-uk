import * as functions from "firebase-functions";

type PrivilegedCacheEntry = {
  value: boolean;
  expiresAtMs: number;
};

const privilegedCache = new Map<string, PrivilegedCacheEntry>();
const cacheTTLms = 30 * 1000;

export async function isPrivilegedCaller(
  context: functions.https.CallableContext,
  db: FirebaseFirestore.Firestore
): Promise<boolean> {
  const userId = context.auth?.uid;
  if (!userId) return false;

  const nowMs = Date.now();
  const cached = privilegedCache.get(userId);
  if (cached && cached.expiresAtMs > nowMs) {
    return cached.value;
  }

  try {
    const adminDoc = await db.collection("admins").doc(userId).get();
    const isPrivileged = adminDoc.exists;
    privilegedCache.set(userId, {
      value: isPrivileged,
      expiresAtMs: nowMs + cacheTTLms,
    });
    return isPrivileged;
  } catch (error) {
    functions.logger.warn("privileged_check_failed", {
      userId,
      error: error instanceof Error ? error.message : "unknown_error",
    });
    return false;
  }
}

export function invalidatePrivilegedCallerCache(userId: string): void {
  privilegedCache.delete(userId);
}
