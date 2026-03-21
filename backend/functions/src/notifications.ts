import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { createHash, createHmac } from "crypto";
import { assertCallableAppCheck } from "./utils/appCheck";
import { Collections, TaskTiming } from "./constants";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();
const ALLOWED_DEVICE_PLATFORMS = new Set(["ios", "android", "web"]);
const MAX_APP_VERSION_LENGTH = 32;
const APP_VERSION_PATTERN = /^[0-9A-Za-z._-]{1,32}$/;
const DEVICE_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;
const MAX_DEVICE_TOKEN_LENGTH = 4096;
const MAX_DEVICE_DOCUMENTS_PER_USER = 50;
const MAX_NOTIFICATION_RETRY_ATTEMPTS = 5;
const NOTIFICATION_RETRY_DELAYS_MINUTES = [5, 15, 60, 180, 720];
const MAX_NOTIFICATION_ERROR_LENGTH = 240;
const DEVICE_TOKEN_QUERY_BATCH_SIZE = 10;
const LOG_PSEUDONYMIZATION_KEY = "LOG_PSEUDONYMIZATION_KEY";
const PERMANENT_MESSAGING_ERROR_CODES = new Set<string>([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
  "messaging/invalid-argument",
]);

type TaskReminderRecord = {
  userId: string;
  type: "task_reminder";
  title: string;
  body: string;
  data: Record<string, string>;
  scheduledFor: admin.firestore.Timestamp;
  sent: boolean;
  sentAt?: admin.firestore.Timestamp;
  error?: string;
  retryCount?: number;
  lastAttemptAt?: admin.firestore.Timestamp;
};

type NotificationDeadLetterRecord = {
  notificationId: string;
  userId: string;
  notificationType: string;
  channel: "push";
  failureReason: string;
  failureCode: string;
  attemptCount: number;
  firstAttemptAt: admin.firestore.Timestamp;
  lastAttemptAt: admin.firestore.Timestamp;
  deadLetteredAt: admin.firestore.Timestamp;
  payload: {
    type: string;
    title: string;
    body: string;
    data: Record<string, string>;
  };
};

type NotificationDeadLetterCollectionLike = {
  doc(id: string): {
    set(
      data: NotificationDeadLetterRecord,
      options?: { merge?: boolean }
    ): Promise<unknown>;
  };
};

type NotificationUpdateRefLike = {
  update(data: Record<string, unknown>): Promise<unknown>;
};

type ContentTask = {
  id: string;
  categoryId?: string;
  title?: string;
  timing?: string;
  priority?: string;
  isPublished?: boolean;
};

type MessagingResponseLike = {
  success: boolean;
  error?: {
    code?: unknown;
  } | null;
};

function parseTimingToDays(timing?: string): number {
  if (!timing) return 0;
  const normalized = timing.trim().toLowerCase().replace(/[\s-]+/g, "_");

  switch (normalized) {
  case TaskTiming.monthBeforeArrival:
    return 30;
  case TaskTiming.weekBeforeArrival:
    return 7;
  case TaskTiming.firstWeek:
    return 7;
  case TaskTiming.firstMonth:
    return 30;
  default:
    break;
  }

  if (normalized.includes("month_before")) return 30;
  if (normalized.includes("week_before")) return 7;
  return 0;
}

function safeString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

function normalizedPlatform(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return null;
  return ALLOWED_DEVICE_PLATFORMS.has(normalized) ? normalized : null;
}

function normalizedAppVersion(value: unknown): string {
  if (typeof value !== "string") return "unknown";
  const normalized = value.trim().slice(0, MAX_APP_VERSION_LENGTH);
  if (!normalized) return "unknown";
  return APP_VERSION_PATTERN.test(normalized) ? normalized : "unknown";
}

function normalizedDeviceID(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized) return null;
  return DEVICE_ID_PATTERN.test(normalized) ? normalized : null;
}

function fallbackDeviceIDFromToken(token: string): string {
  const digest = createHash("sha256").update(token).digest("hex");
  return `legacy_${digest.slice(0, 24)}`;
}

function completedTaskSetFromUserData(userData: admin.firestore.DocumentData): Set<string> {
  const completed = userData?.progress?.completedTasks;
  if (!Array.isArray(completed)) return new Set<string>();
  return new Set(completed.filter((id: unknown) => typeof id === "string"));
}

function queueDocumentID(userId: string, taskId: string, sendAt: Date): string {
  const dayKey = sendAt.toISOString().slice(0, 10);
  return `${userId}_${taskId}_${dayKey}`.replace(/[^A-Za-z0-9_-]/g, "_");
}

function logPseudonymizationKey(): string | null {
  const configured = (
    process.env.LOG_PSEUDONYMIZATION_KEY ||
    functions.config()?.logging?.pseudonymization_key
  ) as string | undefined;
  const normalized = configured?.trim() ?? "";
  return normalized.length > 0 ? normalized : null;
}

function pseudonymizeLogIdentifier(prefix: string, value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  const key = logPseudonymizationKey();
  if (!normalized || !key) return undefined;
  const digest = createHmac("sha256", key).update(normalized).digest("hex");
  return `${prefix}:${digest.slice(0, 12)}`;
}

function buildNotificationAttemptLog(
  notificationId: string,
  userId: string,
  type: string,
  result: "success" | "failure" | "skipped",
  errorMessage?: string
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    notificationRef: pseudonymizeLogIdentifier("notif", notificationId),
    userRef: pseudonymizeLogIdentifier("uid", userId),
    type,
    channel: "push",
    timestamp: new Date().toISOString(),
    result,
    error: errorMessage ? truncateErrorMessage(errorMessage) : undefined,
  };

  return Object.fromEntries(
    Object.entries(payload).filter(([, value]) => value !== undefined)
  );
}

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as { code?: string | number })?.code;
  return code === 6 || code === "6" || code === "already-exists";
}

function normalizedRetryCount(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return Math.floor(parsed);
}

function retryDelayMsForAttempt(attempt: number): number {
  const normalizedAttempt = Math.max(1, Math.floor(attempt));
  const index = Math.min(normalizedAttempt - 1, NOTIFICATION_RETRY_DELAYS_MINUTES.length - 1);
  return NOTIFICATION_RETRY_DELAYS_MINUTES[index] * 60 * 1000;
}

function truncateErrorMessage(message: string): string {
  return message.slice(0, MAX_NOTIFICATION_ERROR_LENGTH);
}

function deadLetterCollectionRef(
  firestore: Pick<FirebaseFirestore.Firestore, "collection"> = db
): NotificationDeadLetterCollectionLike {
  return firestore.collection(Collections.notificationDeadLetter) as NotificationDeadLetterCollectionLike;
}

function buildNotificationDeadLetterRecord(
  notificationId: string,
  notification: TaskReminderRecord,
  attemptCount: number,
  failureReason: string,
  failureCode: string | null,
  deadLetteredAt: admin.firestore.Timestamp = admin.firestore.Timestamp.now()
): NotificationDeadLetterRecord {
  return {
    notificationId,
    userId: pseudonymizeLogIdentifier("uid", notification.userId) ?? "uid:unavailable",
    notificationType: notification.type,
    channel: "push",
    failureReason: truncateErrorMessage(failureReason || "notification_send_failed"),
    failureCode: failureCode ?? "unknown",
    attemptCount,
    firstAttemptAt: notification.scheduledFor,
    lastAttemptAt: notification.lastAttemptAt ?? deadLetteredAt,
    deadLetteredAt,
    payload: {
      type: notification.type,
      title: notification.title,
      body: notification.body,
      data: { ...notification.data },
    },
  };
}

async function persistTerminalNotificationFailure(
  notificationRef: NotificationUpdateRefLike,
  notificationId: string,
  notification: TaskReminderRecord,
  attemptCount: number,
  failureReason: string,
  failureCode: string | null,
  deadLetterCollection: NotificationDeadLetterCollectionLike = deadLetterCollectionRef(),
  deadLetteredAt: admin.firestore.Timestamp = admin.firestore.Timestamp.now()
): Promise<void> {
  const message = truncateErrorMessage(failureReason || "notification_send_failed");
  await notificationRef.update({
    sent: true,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    retryCount: attemptCount,
    error: message,
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    await deadLetterCollection.doc(notificationId).set(
      buildNotificationDeadLetterRecord(
        notificationId,
        notification,
        attemptCount,
        message,
        failureCode,
        deadLetteredAt
      ),
      { merge: true }
    );
  } catch (error) {
    functions.logger.error("notification_dead_letter_write_failed", Object.fromEntries(
      Object.entries({
        notificationRef: pseudonymizeLogIdentifier("notif", notificationId),
        userRef: pseudonymizeLogIdentifier("uid", notification.userId),
        failureCode: failureCode ?? undefined,
        error: truncateErrorMessage(error instanceof Error ? error.message : "dead_letter_write_failed"),
      }).filter(([, value]) => value !== undefined)
    ));
  }
}

function extractMessagingErrorCode(error: unknown): string | null {
  const code = (error as { code?: unknown })?.code;
  if (typeof code === "string" && code.trim().length > 0) {
    return code.trim();
  }
  if (typeof code === "number") {
    return String(code);
  }
  return null;
}

function isPermanentMessagingErrorCode(code: string | null): boolean {
  if (!code) return false;
  return PERMANENT_MESSAGING_ERROR_CODES.has(code);
}

function invalidTokensFromMessagingResponses(
  tokens: string[],
  responses: MessagingResponseLike[]
): string[] {
  const invalidTokens: string[] = [];
  responses.forEach((result, index) => {
    if (result.success) return;
    const code = extractMessagingErrorCode(result.error);
    if (isPermanentMessagingErrorCode(code) && tokens[index]) {
      invalidTokens.push(tokens[index]);
    }
  });
  return invalidTokens;
}

function chunkValues(values: string[], size: number): string[][] {
  if (values.length === 0) return [];
  const chunks: string[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

async function drainQueuedOperations(
  pending: Promise<void>[],
  context: Record<string, unknown>
): Promise<void> {
  if (pending.length == 0) return;

  const batch = pending.splice(0, pending.length);
  const settled = await Promise.allSettled(batch);
  const failed = settled.filter((result) => result.status === "rejected");

  if (failed.length > 0) {
    functions.logger.warn("notification_queue_partial_failures", {
      ...context,
      failedCount: failed.length,
      totalCount: settled.length,
    });
  }
}

async function syncLegacyTokenFromDevices(
  userRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const firstDevice = await userRef
    .collection(Collections.devices)
    .limit(1)
    .get();

  const metadataPatch = {
    metadata: {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };

  if (firstDevice.empty) {
    await userRef.set({
      ...metadataPatch,
      fcmToken: admin.firestore.FieldValue.delete(),
    }, { merge: true });
    return;
  }

  const fallbackToken = safeString(firstDevice.docs[0].data()?.fcmToken, "");
  if (!fallbackToken) {
    await userRef.set({
      ...metadataPatch,
      fcmToken: admin.firestore.FieldValue.delete(),
    }, { merge: true });
    return;
  }

  await userRef.set({
    ...metadataPatch,
    fcmToken: fallbackToken,
  }, { merge: true });
}

async function deleteDeviceDocsByToken(
  userRef: FirebaseFirestore.DocumentReference,
  token: string
): Promise<number> {
  let deletedCount = 0;
  while (true) {
    const snapshot = await userRef
      .collection(Collections.devices)
      .where("fcmToken", "==", token)
      .limit(25)
      .get();

    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    deletedCount += snapshot.size;
    if (snapshot.size < 25) break;
  }
  return deletedCount;
}

async function deleteAllDeviceDocs(userRef: FirebaseFirestore.DocumentReference): Promise<number> {
  let deletedCount = 0;
  while (true) {
    const snapshot = await userRef
      .collection(Collections.devices)
      .limit(25)
      .get();

    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    deletedCount += snapshot.size;
    if (snapshot.size < 25) break;
  }
  return deletedCount;
}

async function removeInvalidTokensForUser(userId: string, invalidTokens: string[]): Promise<void> {
  const uniqueTokens = Array.from(
    new Set(
      invalidTokens
        .map((token) => token.trim())
        .filter((token) => token.length > 0)
    )
  );
  if (uniqueTokens.length === 0) return;

  const userRef = db.collection(Collections.users).doc(userId);

  for (const chunk of chunkValues(uniqueTokens, DEVICE_TOKEN_QUERY_BATCH_SIZE)) {
    const snapshot = await userRef
      .collection(Collections.devices)
      .where("fcmToken", "in", chunk)
      .get();

    if (snapshot.empty) continue;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  const userDoc = await userRef.get();
  const legacyToken = safeString(userDoc.data()?.fcmToken, "");
  if (legacyToken && uniqueTokens.includes(legacyToken)) {
    await syncLegacyTokenFromDevices(userRef);
  }
}

async function scheduleNotificationRetry(
  notifDoc: FirebaseFirestore.QueryDocumentSnapshot,
  notification: TaskReminderRecord,
  nextRetryCount: number,
  reason: string,
  failureCode: string | null = null
): Promise<void> {
  const message = truncateErrorMessage(reason || "notification_send_failed");
  if (nextRetryCount >= MAX_NOTIFICATION_RETRY_ATTEMPTS) {
    await persistTerminalNotificationFailure(
      notifDoc.ref,
      notifDoc.id,
      notification,
      nextRetryCount,
      message,
      failureCode
    );
    return;
  }

  const retryAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + retryDelayMsForAttempt(nextRetryCount)
  );
  await notifDoc.ref.update({
    sent: false,
    retryCount: nextRetryCount,
    scheduledFor: retryAt,
    error: message,
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function buildQueuedNotificationFailureLog(
  notificationId: string,
  userId: string,
  retryCount: number,
  message: string,
  code: string | null
): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries({
      notificationRef: pseudonymizeLogIdentifier("notif", notificationId),
      userRef: pseudonymizeLogIdentifier("uid", userId),
      message: truncateErrorMessage(message),
      failureCode: code ?? undefined,
      retryCount,
    }).filter(([, value]) => value !== undefined)
  );
}

async function processQueuedNotification(
  notifDoc: FirebaseFirestore.QueryDocumentSnapshot,
  tokensForUser: (userId: string) => Promise<string[]>,
  invalidateTokenCacheForUser: (userId: string) => void
): Promise<void> {
  const notif = notifDoc.data() as TaskReminderRecord;
  const retryCount = normalizedRetryCount(notif.retryCount);

  try {
    const tokens = await tokensForUser(notif.userId);

    if (tokens.length === 0) {
      functions.logger.info("notification_delivery", buildNotificationAttemptLog(
        notifDoc.id,
        notif.userId,
        notif.type,
        "skipped",
        "missing_fcm_token"
      ));
      await notifDoc.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        error: "missing_fcm_token",
        retryCount: retryCount + 1,
      });
      return;
    }

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: notif.title,
        body: notif.body,
      },
      data: notif.data,
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    const failedCodes: string[] = [];
    const invalidTokens = invalidTokensFromMessagingResponses(tokens, response.responses);
    response.responses.forEach((result, index) => {
      if (result.success) return;

      const code = extractMessagingErrorCode(result.error);
      if (code) failedCodes.push(code);
    });

    if (invalidTokens.length > 0) {
      await removeInvalidTokensForUser(notif.userId, invalidTokens);
      invalidateTokenCacheForUser(notif.userId);
    }

    if (response.successCount > 0) {
      functions.logger.info("notification_delivery", buildNotificationAttemptLog(
        notifDoc.id,
        notif.userId,
        notif.type,
        "success"
      ));
      await notifDoc.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        error: admin.firestore.FieldValue.delete(),
        retryCount: admin.firestore.FieldValue.delete(),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const allPermanentFailures = failedCodes.length > 0
      && failedCodes.every((code) => isPermanentMessagingErrorCode(code));
    if (allPermanentFailures) {
      functions.logger.warn("notification_delivery", buildNotificationAttemptLog(
        notifDoc.id,
        notif.userId,
        notif.type,
        "failure",
        "all_device_tokens_invalid"
      ));
      await persistTerminalNotificationFailure(
        notifDoc.ref,
        notifDoc.id,
        notif,
        retryCount + 1,
        "all_device_tokens_invalid",
        failedCodes[0] ?? null
      );
      return;
    }

    await scheduleNotificationRetry(
      notifDoc,
      notif,
      retryCount + 1,
      failedCodes[0] ?? "notification_send_failed",
      failedCodes[0] ?? null
    );
    functions.logger.warn("notification_delivery", buildNotificationAttemptLog(
      notifDoc.id,
      notif.userId,
      notif.type,
      "failure",
      failedCodes[0] ?? "notification_send_failed"
    ));
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown_error";
    const code = extractMessagingErrorCode(error);

    if (isPermanentMessagingErrorCode(code)) {
      await persistTerminalNotificationFailure(
        notifDoc.ref,
        notifDoc.id,
        notif,
        retryCount + 1,
        message,
        code
      );
      return;
    }

    await scheduleNotificationRetry(notifDoc, notif, retryCount + 1, message, code);
    functions.logger.warn("notification_delivery", buildNotificationAttemptLog(
      notifDoc.id,
      notif.userId,
      notif.type,
      "failure",
      message
    ));
    functions.logger.error("Failed to send queued notification", buildQueuedNotificationFailureLog(
      notifDoc.id,
      notif.userId,
      retryCount + 1,
      message,
      code
    ));
  }
}

async function queueReminder(
  userId: string,
  task: ContentTask,
  daysUntilArrival: number
): Promise<void> {
  const now = new Date();
  const sendAt = new Date(now);
  sendAt.setHours(9, 0, 0, 0);

  // If it's already past 9AM local, push to tomorrow.
  if (sendAt <= now) {
    sendAt.setDate(sendAt.getDate() + 1);
  }

  const title = task.priority?.toLowerCase() === "must do" ? "⚠️ Important task" : "Task reminder";
  const body = safeString(task.title, "You have an upcoming checklist task.");

  const doc: TaskReminderRecord = {
    userId,
    type: "task_reminder",
    title,
    body,
    data: {
      type: "task_reminder",
      taskId: task.id,
      categoryId: safeString(task.categoryId, "unknown"),
      daysUntilArrival: String(daysUntilArrival),
    },
    scheduledFor: admin.firestore.Timestamp.fromDate(sendAt),
    sent: false,
    retryCount: 0,
  };

  const queueRef = db
    .collection(Collections.notifications.root)
    .doc(Collections.notifications.queue)
    .collection(Collections.notifications.pending)
    .doc(queueDocumentID(userId, task.id, sendAt));

  try {
    await queueRef.create(doc);
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return;
    }
    throw error;
  }
}

async function getPublishedTasks(): Promise<ContentTask[]> {
  // This follows the current scaffold's nested "items" convention.
  const snapshot = await db
    .collection(Collections.content.root)
    .doc(Collections.content.tasks)
    .collection(Collections.content.items)
    .where("isPublished", "==", true)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...(doc.data() as Omit<ContentTask, "id">),
  }));
}

export const scheduleTaskNotifications = functions.pubsub
  .schedule("every day 08:00")
  .timeZone("Europe/London")
  .onRun(async () => {
    const minimumArrivalDate = admin.firestore.Timestamp.fromDate(new Date("2000-01-01T00:00:00.000Z"));
    const allTasks = await getPublishedTasks();
    if (allTasks.length === 0) return null;

    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const userPageSize = 500;
    const queueBatchSize = 24;
    const queueOperations: Promise<void>[] = [];
    let lastUserDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    let processedUsers = 0;

    while (true) {
      let usersQuery = db
        .collection(Collections.users)
        .where("preferences.notifications.taskReminders", "==", true)
        .where("profile.arrivalDate", ">=", minimumArrivalDate)
        .orderBy("profile.arrivalDate")
        .limit(userPageSize);

      if (lastUserDoc) {
        usersQuery = usersQuery.startAfter(lastUserDoc);
      }

      const usersPage = await usersQuery.get();
      if (usersPage.empty) break;

      for (const userDoc of usersPage.docs) {
        processedUsers += 1;
        const userId = userDoc.id;
        const userData = userDoc.data();

        const arrivalTs = userData.profile?.arrivalDate as admin.firestore.Timestamp | undefined;
        if (!arrivalTs) continue;

        const arrivalDate = arrivalTs.toDate();
        const daysUntilArrival = Math.ceil(
          (arrivalDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        );

        const completedSet = completedTaskSetFromUserData(userData);

        for (const task of allTasks) {
          if (!task.id || completedSet.has(task.id)) continue;
          const dueDays = parseTimingToDays(task.timing);

          // Send reminder at due point and one day before the due point.
          const shouldRemind = daysUntilArrival <= dueDays && daysUntilArrival >= dueDays - 1;
          if (!shouldRemind) continue;

          queueOperations.push(queueReminder(userId, task, daysUntilArrival));
          if (queueOperations.length >= queueBatchSize) {
            await drainQueuedOperations(queueOperations, {
              phase: "schedule",
              userRef: pseudonymizeLogIdentifier("uid", userId),
            });
          }
        }
      }

      lastUserDoc = usersPage.docs[usersPage.docs.length - 1];
      if (usersPage.size < userPageSize) break;
    }

    await drainQueuedOperations(queueOperations, { phase: "schedule_flush" });

    functions.logger.info("Scheduled task reminders", { processedUsers });
    return null;
  });

export const sendQueuedNotifications = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const pending = await db
      .collection(Collections.notifications.root)
      .doc(Collections.notifications.queue)
      .collection(Collections.notifications.pending)
      .where("sent", "==", false)
      .where("scheduledFor", "<=", now)
      .orderBy("scheduledFor", "asc")
      .limit(100)
      .get();

    if (pending.empty) return null;

    const tokenCache = new Map<string, string[]>();
    const tokensForUser = async (userId: string): Promise<string[]> => {
      if (tokenCache.has(userId)) return tokenCache.get(userId) ?? [];

      const userRef = db.collection(Collections.users).doc(userId);
      const [deviceSnapshot, userDoc] = await Promise.all([
        userRef
          .collection(Collections.devices)
          .limit(MAX_DEVICE_DOCUMENTS_PER_USER)
          .get(),
        userRef.get(),
      ]);

      const tokenSet = new Set<string>();
      for (const deviceDoc of deviceSnapshot.docs) {
        const token = safeString(deviceDoc.data()?.fcmToken, "");
        if (token && token.length <= MAX_DEVICE_TOKEN_LENGTH) {
          tokenSet.add(token);
        }
      }

      const legacyToken = safeString(userDoc.data()?.fcmToken, "");
      if (legacyToken && legacyToken.length <= MAX_DEVICE_TOKEN_LENGTH) {
        tokenSet.add(legacyToken);
      }

      const tokens = Array.from(tokenSet);
      tokenCache.set(userId, tokens);
      return tokens;
    };

    const invalidateTokenCacheForUser = (userId: string): void => {
      tokenCache.delete(userId);
    };

    const maxConcurrentDispatches = 20;
    const dispatchOperations: Promise<void>[] = [];

    for (const notifDoc of pending.docs) {
      dispatchOperations.push(
        processQueuedNotification(notifDoc, tokensForUser, invalidateTokenCacheForUser)
      );
      if (dispatchOperations.length >= maxConcurrentDispatches) {
        await drainQueuedOperations(dispatchOperations, {
          phase: "dispatch",
        });
      }
    }

    await drainQueuedOperations(dispatchOperations, { phase: "dispatch_flush" });
    return null;
  });

export const scanNotificationDeadLetterBacklog = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
    const snapshot = await db
      .collection(Collections.notificationDeadLetter)
      .where("deadLetteredAt", "<=", cutoff)
      .limit(100)
      .get();

    if (!snapshot.empty) {
      functions.logger.warn("notification_dead_letter_backlog", {
        count: snapshot.size,
      });
    }

    return null;
  });

export const registerDeviceToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  assertCallableAppCheck(context, "registerDeviceToken");

  const token = safeString(data?.fcmToken, "");
  if (!token || token.length > MAX_DEVICE_TOKEN_LENGTH) {
    throw new functions.https.HttpsError("invalid-argument", "fcmToken is required");
  }

  const platform = normalizedPlatform(data?.platform);
  if (!platform) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "platform must be one of: ios, android, web"
    );
  }
  const appVersion = normalizedAppVersion(data?.appVersion);
  const deviceID = normalizedDeviceID(data?.deviceId) ?? fallbackDeviceIDFromToken(token);

  const userRef = db.collection(Collections.users).doc(context.auth.uid);
  const deviceRef = userRef.collection(Collections.devices).doc(deviceID);

  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(deviceRef);

    const devicePayload: Record<string, unknown> = {
      fcmToken: token,
      platform,
      appVersion,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      devicePayload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    transaction.set(deviceRef, devicePayload, { merge: true });
    transaction.set(userRef, {
      fcmToken: token,
      metadata: {
        platform,
        appVersion,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });
  });

  return { success: true, deviceId: deviceID };
});

export const unregisterDeviceToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  assertCallableAppCheck(context, "unregisterDeviceToken");

  const userRef = db.collection(Collections.users).doc(context.auth.uid);
  const deviceID = normalizedDeviceID(data?.deviceId);
  const token = safeString(data?.fcmToken, "");
  if (token.length > MAX_DEVICE_TOKEN_LENGTH) {
    throw new functions.https.HttpsError("invalid-argument", "fcmToken is invalid");
  }

  if (!deviceID && !token) {
    await deleteAllDeviceDocs(userRef);
    await userRef.set({
      fcmToken: admin.firestore.FieldValue.delete(),
      metadata: {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    }, { merge: true });
    return { success: true, mode: "legacy" };
  }

  if (deviceID) {
    await userRef.collection(Collections.devices).doc(deviceID).delete().catch(() => undefined);
  }

  if (token) {
    await deleteDeviceDocsByToken(userRef, token);
  }

  await syncLegacyTokenFromDevices(userRef);
  return { success: true };
});

export const __private__ = {
  parseTimingToDays,
  normalizedPlatform,
  normalizedAppVersion,
  normalizedDeviceID,
  retryDelayMsForAttempt,
  isPermanentMessagingErrorCode,
  queueDocumentID,
  buildNotificationAttemptLog,
  buildQueuedNotificationFailureLog,
  buildNotificationDeadLetterRecord,
  persistTerminalNotificationFailure,
  pseudonymizeLogIdentifier,
  invalidTokensFromMessagingResponses,
};
