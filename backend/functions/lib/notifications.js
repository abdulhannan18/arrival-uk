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
exports.__private__ = exports.unregisterDeviceToken = exports.registerDeviceToken = exports.sendQueuedNotifications = exports.scheduleTaskNotifications = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const crypto_1 = require("crypto");
const appCheck_1 = require("./utils/appCheck");
const constants_1 = require("./constants");
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
const PERMANENT_MESSAGING_ERROR_CODES = new Set([
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
    "messaging/invalid-argument",
]);
function parseTimingToDays(timing) {
    if (!timing)
        return 0;
    const normalized = timing.trim().toLowerCase().replace(/[\s-]+/g, "_");
    switch (normalized) {
        case constants_1.TaskTiming.monthBeforeArrival:
            return 30;
        case constants_1.TaskTiming.weekBeforeArrival:
            return 7;
        case constants_1.TaskTiming.firstWeek:
            return 7;
        case constants_1.TaskTiming.firstMonth:
            return 30;
        default:
            break;
    }
    if (normalized.includes("month_before"))
        return 30;
    if (normalized.includes("week_before"))
        return 7;
    return 0;
}
function safeString(value, fallback) {
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}
function normalizedPlatform(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.trim().toLowerCase();
    if (!normalized)
        return null;
    return ALLOWED_DEVICE_PLATFORMS.has(normalized) ? normalized : null;
}
function normalizedAppVersion(value) {
    if (typeof value !== "string")
        return "unknown";
    const normalized = value.trim().slice(0, MAX_APP_VERSION_LENGTH);
    if (!normalized)
        return "unknown";
    return APP_VERSION_PATTERN.test(normalized) ? normalized : "unknown";
}
function normalizedDeviceID(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.trim();
    if (!normalized)
        return null;
    return DEVICE_ID_PATTERN.test(normalized) ? normalized : null;
}
function fallbackDeviceIDFromToken(token) {
    const digest = (0, crypto_1.createHash)("sha256").update(token).digest("hex");
    return `legacy_${digest.slice(0, 24)}`;
}
function completedTaskSetFromUserData(userData) {
    const completed = userData?.progress?.completedTasks;
    if (!Array.isArray(completed))
        return new Set();
    return new Set(completed.filter((id) => typeof id === "string"));
}
function queueDocumentID(userId, taskId, sendAt) {
    const dayKey = sendAt.toISOString().slice(0, 10);
    return `${userId}_${taskId}_${dayKey}`.replace(/[^A-Za-z0-9_-]/g, "_");
}
function buildNotificationAttemptLog(notificationId, userId, type, result, errorMessage) {
    return {
        notificationId,
        userId,
        type,
        channel: "push",
        timestamp: new Date().toISOString(),
        result,
        error: errorMessage ? truncateErrorMessage(errorMessage) : undefined,
    };
}
function isAlreadyExistsError(error) {
    const code = error?.code;
    return code === 6 || code === "6" || code === "already-exists";
}
function normalizedRetryCount(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0)
        return 0;
    return Math.floor(parsed);
}
function retryDelayMsForAttempt(attempt) {
    const normalizedAttempt = Math.max(1, Math.floor(attempt));
    const index = Math.min(normalizedAttempt - 1, NOTIFICATION_RETRY_DELAYS_MINUTES.length - 1);
    return NOTIFICATION_RETRY_DELAYS_MINUTES[index] * 60 * 1000;
}
function truncateErrorMessage(message) {
    return message.slice(0, MAX_NOTIFICATION_ERROR_LENGTH);
}
function extractMessagingErrorCode(error) {
    const code = error?.code;
    if (typeof code === "string" && code.trim().length > 0) {
        return code.trim();
    }
    if (typeof code === "number") {
        return String(code);
    }
    return null;
}
function isPermanentMessagingErrorCode(code) {
    if (!code)
        return false;
    return PERMANENT_MESSAGING_ERROR_CODES.has(code);
}
function invalidTokensFromMessagingResponses(tokens, responses) {
    const invalidTokens = [];
    responses.forEach((result, index) => {
        if (result.success)
            return;
        const code = extractMessagingErrorCode(result.error);
        if (isPermanentMessagingErrorCode(code) && tokens[index]) {
            invalidTokens.push(tokens[index]);
        }
    });
    return invalidTokens;
}
function chunkValues(values, size) {
    if (values.length === 0)
        return [];
    const chunks = [];
    for (let index = 0; index < values.length; index += size) {
        chunks.push(values.slice(index, index + size));
    }
    return chunks;
}
async function drainQueuedOperations(pending, context) {
    if (pending.length == 0)
        return;
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
async function syncLegacyTokenFromDevices(userRef) {
    const firstDevice = await userRef
        .collection(constants_1.Collections.devices)
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
async function deleteDeviceDocsByToken(userRef, token) {
    let deletedCount = 0;
    while (true) {
        const snapshot = await userRef
            .collection(constants_1.Collections.devices)
            .where("fcmToken", "==", token)
            .limit(25)
            .get();
        if (snapshot.empty)
            break;
        const batch = db.batch();
        for (const doc of snapshot.docs) {
            batch.delete(doc.ref);
        }
        await batch.commit();
        deletedCount += snapshot.size;
        if (snapshot.size < 25)
            break;
    }
    return deletedCount;
}
async function deleteAllDeviceDocs(userRef) {
    let deletedCount = 0;
    while (true) {
        const snapshot = await userRef
            .collection(constants_1.Collections.devices)
            .limit(25)
            .get();
        if (snapshot.empty)
            break;
        const batch = db.batch();
        for (const doc of snapshot.docs) {
            batch.delete(doc.ref);
        }
        await batch.commit();
        deletedCount += snapshot.size;
        if (snapshot.size < 25)
            break;
    }
    return deletedCount;
}
async function removeInvalidTokensForUser(userId, invalidTokens) {
    const uniqueTokens = Array.from(new Set(invalidTokens
        .map((token) => token.trim())
        .filter((token) => token.length > 0)));
    if (uniqueTokens.length === 0)
        return;
    const userRef = db.collection(constants_1.Collections.users).doc(userId);
    for (const chunk of chunkValues(uniqueTokens, DEVICE_TOKEN_QUERY_BATCH_SIZE)) {
        const snapshot = await userRef
            .collection(constants_1.Collections.devices)
            .where("fcmToken", "in", chunk)
            .get();
        if (snapshot.empty)
            continue;
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
async function scheduleNotificationRetry(notificationRef, nextRetryCount, reason) {
    const message = truncateErrorMessage(reason || "notification_send_failed");
    if (nextRetryCount >= MAX_NOTIFICATION_RETRY_ATTEMPTS) {
        await notificationRef.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            retryCount: nextRetryCount,
            error: message,
            lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
    }
    const retryAt = admin.firestore.Timestamp.fromMillis(Date.now() + retryDelayMsForAttempt(nextRetryCount));
    await notificationRef.update({
        sent: false,
        retryCount: nextRetryCount,
        scheduledFor: retryAt,
        error: message,
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function processQueuedNotification(notifDoc, tokensForUser, invalidateTokenCacheForUser) {
    const notif = notifDoc.data();
    const retryCount = normalizedRetryCount(notif.retryCount);
    try {
        const tokens = await tokensForUser(notif.userId);
        if (tokens.length === 0) {
            functions.logger.info("notification_delivery", buildNotificationAttemptLog(notifDoc.id, notif.userId, notif.type, "skipped", "missing_fcm_token"));
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
        const failedCodes = [];
        const invalidTokens = invalidTokensFromMessagingResponses(tokens, response.responses);
        response.responses.forEach((result, index) => {
            if (result.success)
                return;
            const code = extractMessagingErrorCode(result.error);
            if (code)
                failedCodes.push(code);
        });
        if (invalidTokens.length > 0) {
            await removeInvalidTokensForUser(notif.userId, invalidTokens);
            invalidateTokenCacheForUser(notif.userId);
        }
        if (response.successCount > 0) {
            functions.logger.info("notification_delivery", buildNotificationAttemptLog(notifDoc.id, notif.userId, notif.type, "success"));
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
            functions.logger.warn("notification_delivery", buildNotificationAttemptLog(notifDoc.id, notif.userId, notif.type, "failure", "all_device_tokens_invalid"));
            await notifDoc.ref.update({
                sent: true,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                retryCount: retryCount + 1,
                error: "all_device_tokens_invalid",
                lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
        }
        await scheduleNotificationRetry(notifDoc.ref, retryCount + 1, failedCodes[0] ?? "notification_send_failed");
        functions.logger.warn("notification_delivery", buildNotificationAttemptLog(notifDoc.id, notif.userId, notif.type, "failure", failedCodes[0] ?? "notification_send_failed"));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "unknown_error";
        const code = extractMessagingErrorCode(error);
        if (isPermanentMessagingErrorCode(code)) {
            await notifDoc.ref.update({
                sent: true,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                retryCount: retryCount + 1,
                error: truncateErrorMessage(message),
                lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
        }
        await scheduleNotificationRetry(notifDoc.ref, retryCount + 1, message);
        functions.logger.warn("notification_delivery", buildNotificationAttemptLog(notifDoc.id, notif.userId, notif.type, "failure", message));
        functions.logger.error("Failed to send queued notification", {
            notificationId: notifDoc.id,
            message: truncateErrorMessage(message),
            code,
            retryCount: retryCount + 1,
        });
    }
}
async function queueReminder(userId, task, daysUntilArrival) {
    const now = new Date();
    const sendAt = new Date(now);
    sendAt.setHours(9, 0, 0, 0);
    // If it's already past 9AM local, push to tomorrow.
    if (sendAt <= now) {
        sendAt.setDate(sendAt.getDate() + 1);
    }
    const title = task.priority?.toLowerCase() === "must do" ? "⚠️ Important task" : "Task reminder";
    const body = safeString(task.title, "You have an upcoming checklist task.");
    const doc = {
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
        .collection(constants_1.Collections.notifications.root)
        .doc(constants_1.Collections.notifications.queue)
        .collection(constants_1.Collections.notifications.pending)
        .doc(queueDocumentID(userId, task.id, sendAt));
    try {
        await queueRef.create(doc);
    }
    catch (error) {
        if (isAlreadyExistsError(error)) {
            return;
        }
        throw error;
    }
}
async function getPublishedTasks() {
    // This follows the current scaffold's nested "items" convention.
    const snapshot = await db
        .collection(constants_1.Collections.content.root)
        .doc(constants_1.Collections.content.tasks)
        .collection(constants_1.Collections.content.items)
        .where("isPublished", "==", true)
        .get();
    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
    }));
}
exports.scheduleTaskNotifications = functions.pubsub
    .schedule("every day 08:00")
    .timeZone("Europe/London")
    .onRun(async () => {
    const minimumArrivalDate = admin.firestore.Timestamp.fromDate(new Date("2000-01-01T00:00:00.000Z"));
    const allTasks = await getPublishedTasks();
    if (allTasks.length === 0)
        return null;
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const userPageSize = 500;
    const queueBatchSize = 24;
    const queueOperations = [];
    let lastUserDoc;
    let processedUsers = 0;
    while (true) {
        let usersQuery = db
            .collection(constants_1.Collections.users)
            .where("preferences.notifications.taskReminders", "==", true)
            .where("profile.arrivalDate", ">=", minimumArrivalDate)
            .orderBy("profile.arrivalDate")
            .limit(userPageSize);
        if (lastUserDoc) {
            usersQuery = usersQuery.startAfter(lastUserDoc);
        }
        const usersPage = await usersQuery.get();
        if (usersPage.empty)
            break;
        for (const userDoc of usersPage.docs) {
            processedUsers += 1;
            const userId = userDoc.id;
            const userData = userDoc.data();
            const arrivalTs = userData.profile?.arrivalDate;
            if (!arrivalTs)
                continue;
            const arrivalDate = arrivalTs.toDate();
            const daysUntilArrival = Math.ceil((arrivalDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
            const completedSet = completedTaskSetFromUserData(userData);
            for (const task of allTasks) {
                if (!task.id || completedSet.has(task.id))
                    continue;
                const dueDays = parseTimingToDays(task.timing);
                // Send reminder at due point and one day before the due point.
                const shouldRemind = daysUntilArrival <= dueDays && daysUntilArrival >= dueDays - 1;
                if (!shouldRemind)
                    continue;
                queueOperations.push(queueReminder(userId, task, daysUntilArrival));
                if (queueOperations.length >= queueBatchSize) {
                    await drainQueuedOperations(queueOperations, {
                        phase: "schedule",
                        userId,
                    });
                }
            }
        }
        lastUserDoc = usersPage.docs[usersPage.docs.length - 1];
        if (usersPage.size < userPageSize)
            break;
    }
    await drainQueuedOperations(queueOperations, { phase: "schedule_flush" });
    functions.logger.info("Scheduled task reminders", { processedUsers });
    return null;
});
exports.sendQueuedNotifications = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const pending = await db
        .collection(constants_1.Collections.notifications.root)
        .doc(constants_1.Collections.notifications.queue)
        .collection(constants_1.Collections.notifications.pending)
        .where("sent", "==", false)
        .where("scheduledFor", "<=", now)
        .orderBy("scheduledFor", "asc")
        .limit(100)
        .get();
    if (pending.empty)
        return null;
    const tokenCache = new Map();
    const tokensForUser = async (userId) => {
        if (tokenCache.has(userId))
            return tokenCache.get(userId) ?? [];
        const userRef = db.collection(constants_1.Collections.users).doc(userId);
        const [deviceSnapshot, userDoc] = await Promise.all([
            userRef
                .collection(constants_1.Collections.devices)
                .limit(MAX_DEVICE_DOCUMENTS_PER_USER)
                .get(),
            userRef.get(),
        ]);
        const tokenSet = new Set();
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
    const invalidateTokenCacheForUser = (userId) => {
        tokenCache.delete(userId);
    };
    const maxConcurrentDispatches = 20;
    const dispatchOperations = [];
    for (const notifDoc of pending.docs) {
        dispatchOperations.push(processQueuedNotification(notifDoc, tokensForUser, invalidateTokenCacheForUser));
        if (dispatchOperations.length >= maxConcurrentDispatches) {
            await drainQueuedOperations(dispatchOperations, {
                phase: "dispatch",
            });
        }
    }
    await drainQueuedOperations(dispatchOperations, { phase: "dispatch_flush" });
    return null;
});
exports.registerDeviceToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    (0, appCheck_1.assertCallableAppCheck)(context, "registerDeviceToken");
    const token = safeString(data?.fcmToken, "");
    if (!token || token.length > MAX_DEVICE_TOKEN_LENGTH) {
        throw new functions.https.HttpsError("invalid-argument", "fcmToken is required");
    }
    const platform = normalizedPlatform(data?.platform);
    if (!platform) {
        throw new functions.https.HttpsError("invalid-argument", "platform must be one of: ios, android, web");
    }
    const appVersion = normalizedAppVersion(data?.appVersion);
    const deviceID = normalizedDeviceID(data?.deviceId) ?? fallbackDeviceIDFromToken(token);
    const userRef = db.collection(constants_1.Collections.users).doc(context.auth.uid);
    const deviceRef = userRef.collection(constants_1.Collections.devices).doc(deviceID);
    await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(deviceRef);
        const devicePayload = {
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
exports.unregisterDeviceToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    (0, appCheck_1.assertCallableAppCheck)(context, "unregisterDeviceToken");
    const userRef = db.collection(constants_1.Collections.users).doc(context.auth.uid);
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
        await userRef.collection(constants_1.Collections.devices).doc(deviceID).delete().catch(() => undefined);
    }
    if (token) {
        await deleteDeviceDocsByToken(userRef, token);
    }
    await syncLegacyTokenFromDevices(userRef);
    return { success: true };
});
exports.__private__ = {
    parseTimingToDays,
    normalizedPlatform,
    normalizedAppVersion,
    normalizedDeviceID,
    retryDelayMsForAttempt,
    isPermanentMessagingErrorCode,
    queueDocumentID,
    buildNotificationAttemptLog,
    invalidTokensFromMessagingResponses,
};
//# sourceMappingURL=notifications.js.map