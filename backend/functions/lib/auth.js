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
exports.retryFailedUserCleanup = exports.pruneExpiredAnalyticsEvents = exports.verifyUser = exports.recordAnalyticsEvent = exports.trackLogin = exports.onUserDelete = exports.onUserCreate = exports.__private__ = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const crypto_1 = require("crypto");
const appCheck_1 = require("./utils/appCheck");
const constants_1 = require("./constants");
const rateLimit_1 = require("./utils/rateLimit");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const MAX_DISPLAY_NAME_LENGTH = 120;
const MAX_PLATFORM_LENGTH = 32;
const MAX_APP_VERSION_LENGTH = 32;
const MAX_CLEANUP_RETRY_ATTEMPTS = 7;
const ALLOWED_LOGIN_PLATFORMS = new Set(["ios", "android", "web"]);
const APP_VERSION_PATTERN = /^[0-9A-Za-z._-]{1,32}$/;
const MAX_ANALYTICS_EVENT_TYPE_LENGTH = 64;
const MAX_ANALYTICS_PROPERTY_KEYS = 40;
const MAX_ANALYTICS_PROPERTY_KEY_LENGTH = 40;
const MAX_ANALYTICS_PROPERTY_STRING_LENGTH = 160;
const ANALYTICS_RATE_LIMIT_MAX = 120;
const ANALYTICS_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const TRACK_LOGIN_RATE_LIMIT_MAX = 60;
const TRACK_LOGIN_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const VERIFY_USER_RATE_LIMIT_MAX = 120;
const VERIFY_USER_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
function generateReferralCode() {
    // 12 hex chars = 48 bits of entropy (~281 trillion combinations).
    return (0, crypto_1.randomBytes)(6).toString("hex").toUpperCase();
}
function normalizedDisplayName(value) {
    const trimmed = value?.trim() ?? "";
    if (!trimmed)
        return null;
    return trimmed.slice(0, MAX_DISPLAY_NAME_LENGTH);
}
function normalizedPhotoURL(value) {
    const trimmed = value?.trim() ?? "";
    if (!trimmed)
        return null;
    try {
        const parsed = new URL(trimmed);
        if (parsed.protocol !== "https:") {
            return null;
        }
        return parsed.toString();
    }
    catch {
        return null;
    }
}
function normalizedField(value, maxLength, fallback = "unknown") {
    if (typeof value !== "string")
        return fallback;
    const trimmed = value.trim();
    if (!trimmed)
        return fallback;
    return trimmed.slice(0, maxLength);
}
function normalizedPlatform(value) {
    const normalized = normalizedField(value, MAX_PLATFORM_LENGTH).toLowerCase();
    if (!ALLOWED_LOGIN_PLATFORMS.has(normalized)) {
        return "unknown";
    }
    return normalized;
}
function normalizedAppVersion(value) {
    const normalized = normalizedField(value, MAX_APP_VERSION_LENGTH);
    if (!APP_VERSION_PATTERN.test(normalized)) {
        return "unknown";
    }
    return normalized;
}
function isAlreadyExistsError(error) {
    const code = error?.code;
    return code === 6 || code === "6" || code === "already-exists";
}
function sanitizeAnalyticsEventType(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.trim();
    if (!normalized)
        return null;
    return normalized.slice(0, MAX_ANALYTICS_EVENT_TYPE_LENGTH);
}
function isRecord(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function sanitizeAnalyticsProperties(value) {
    if (!isRecord(value))
        return {};
    const sanitized = {};
    let accepted = 0;
    for (const [rawKey, rawValue] of Object.entries(value)) {
        if (accepted >= MAX_ANALYTICS_PROPERTY_KEYS)
            break;
        const key = rawKey.trim().slice(0, MAX_ANALYTICS_PROPERTY_KEY_LENGTH);
        if (!key)
            continue;
        if (typeof rawValue === "string") {
            sanitized[key] = rawValue.slice(0, MAX_ANALYTICS_PROPERTY_STRING_LENGTH);
            accepted += 1;
            continue;
        }
        if (typeof rawValue === "boolean") {
            sanitized[key] = rawValue;
            accepted += 1;
            continue;
        }
        if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
            sanitized[key] = rawValue;
            accepted += 1;
        }
    }
    return sanitized;
}
exports.__private__ = {
    generateReferralCode,
    normalizedPlatform,
    normalizedAppVersion,
    sanitizeAnalyticsEventType,
    sanitizeAnalyticsProperties,
};
function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
async function recursiveDeleteWithRetry(reference, maxAttempts = 3) {
    let attempt = 0;
    while (attempt < maxAttempts) {
        attempt += 1;
        try {
            await db.recursiveDelete(reference);
            return;
        }
        catch (error) {
            const isLastAttempt = attempt >= maxAttempts;
            functions.logger.warn("recursiveDelete attempt failed", {
                path: reference.path,
                attempt,
                maxAttempts,
                error: error instanceof Error ? error.message : "unknown_error",
            });
            if (isLastAttempt) {
                throw error;
            }
            const backoffMs = 250 * Math.pow(2, attempt - 1);
            await wait(backoffMs);
        }
    }
}
async function deleteQueryResultsInBatches(query, batchSize = 200) {
    let deleted = 0;
    while (true) {
        const snapshot = await query.limit(batchSize).get();
        if (snapshot.empty)
            break;
        const batch = db.batch();
        for (const doc of snapshot.docs) {
            batch.delete(doc.ref);
        }
        await batch.commit();
        deleted += snapshot.size;
        if (snapshot.size < batchSize)
            break;
    }
    return deleted;
}
async function deleteSupportTicketsForUser(userId) {
    let deletedTickets = 0;
    while (true) {
        const tickets = await db
            .collection(constants_1.Collections.support.root)
            .doc(constants_1.Collections.support.tickets)
            .collection(constants_1.Collections.support.items)
            .where("userId", "==", userId)
            .limit(25)
            .get();
        if (tickets.empty)
            break;
        for (const ticket of tickets.docs) {
            await recursiveDeleteWithRetry(ticket.ref, 3);
            deletedTickets += 1;
        }
    }
    return deletedTickets;
}
async function cleanupUserScopedCollections(userId) {
    const analyticsDeleted = await deleteQueryResultsInBatches(db.collection(constants_1.Collections.analytics.root)
        .doc(constants_1.Collections.analytics.events)
        .collection(constants_1.Collections.analytics.items)
        .where("userId", "==", userId), 300);
    const referralsOwnedDeleted = await deleteQueryResultsInBatches(db.collection(constants_1.Collections.referrals).where("ownerUserId", "==", userId), 200);
    const referralsAttributedDeleted = await deleteQueryResultsInBatches(db.collection(constants_1.Collections.referrals).where("referredByUserId", "==", userId), 200);
    const ticketsDeleted = await deleteSupportTicketsForUser(userId);
    await db.collection(constants_1.Collections.admins).doc(userId).delete().catch(() => undefined);
    functions.logger.info("User scoped cleanup complete", {
        userId,
        analyticsDeleted,
        referralsOwnedDeleted,
        referralsAttributedDeleted,
        ticketsDeleted,
    });
}
function userDeletionCleanupQueueRef(userId) {
    return db.collection(constants_1.Collections.ops.root)
        .doc(constants_1.Collections.ops.userDeletionCleanupQueue)
        .collection(constants_1.Collections.ops.items)
        .doc(userId);
}
async function enqueueUserCleanupRetry(userId, failures) {
    await userDeletionCleanupQueueRef(userId).set({
        userId,
        failures: failures.slice(0, 20),
        attempts: admin.firestore.FieldValue.increment(1),
        status: "pending",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function runUserDeletionCleanup(userId) {
    const failures = [];
    const userRef = db.collection(constants_1.Collections.users).doc(userId);
    try {
        await recursiveDeleteWithRetry(userRef);
    }
    catch (error) {
        failures.push(`users/${userId}:${error instanceof Error ? error.message : "delete_failed"}`);
    }
    try {
        await cleanupUserScopedCollections(userId);
    }
    catch (error) {
        failures.push(`scoped_cleanup:${error instanceof Error ? error.message : "cleanup_failed"}`);
    }
    return failures;
}
async function trackAnalyticsEvent(userId, eventType, properties, options) {
    const retentionDays = 180;
    const ttlMs = retentionDays * 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + ttlMs);
    const platform = options?.platform ?? "backend";
    const appVersion = options?.appVersion ?? "cloud_function";
    await db.collection(constants_1.Collections.analytics.root)
        .doc(constants_1.Collections.analytics.events)
        .collection(constants_1.Collections.analytics.items)
        .add({
        userId,
        eventType,
        properties,
        platform,
        appVersion,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
    });
}
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    const authProvider = (() => {
        const providerId = user.providerData?.[0]?.providerId;
        if (providerId === "google.com")
            return "google";
        if (providerId === "apple.com")
            return "apple";
        return "email";
    })();
    const displayName = normalizedDisplayName(user.displayName);
    const photoURL = normalizedPhotoURL(user.photoURL);
    const userRef = db.collection(constants_1.Collections.users).doc(user.uid);
    const maxReferralGenerationAttempts = 5;
    let initializedReferralCode = null;
    for (let attempt = 1; attempt <= maxReferralGenerationAttempts; attempt += 1) {
        const referralCode = generateReferralCode();
        const referralRef = db.collection(constants_1.Collections.referrals).doc(referralCode);
        const batch = db.batch();
        batch.set(userRef, {
            userId: user.uid,
            email: user.email ?? null,
            displayName,
            photoURL,
            authProvider,
            profile: {
                university: null,
                course: null,
                studyLevel: null,
                city: null,
                arrivalDate: null,
                nationality: null,
                homeCurrency: null,
                accommodationType: null,
                visaType: null,
            },
            preferences: {
                language: "en",
                notifications: {
                    taskReminders: true,
                    weeklyDigest: true,
                    productUpdates: false,
                },
                privacy: {
                    allowAnalytics: false,
                    allowPersonalizedAds: false,
                    dataSharing: false,
                },
            },
            progress: {
                completedTasks: [],
                totalTasks: 0,
                completionRate: 0,
                lastActivityDate: admin.firestore.FieldValue.serverTimestamp(),
            },
            engagement: {
                daysSinceSignup: 0,
                loginCount: 1,
                lastLoginDate: admin.firestore.FieldValue.serverTimestamp(),
                referralCode,
                referredBy: null,
            },
            monetization: {
                isPremium: false,
                premiumExpiryDate: null,
                lifetimeValue: 0,
                adImpressions: 0,
                affiliateClicks: 0,
            },
            metadata: {
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: 1,
                platform: "unknown",
                appVersion: "unknown",
            },
        }, { merge: true });
        batch.create(referralRef, {
            referralCode,
            ownerUserId: user.uid,
            referredByUserId: null,
            totalReferrals: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        try {
            await batch.commit();
            initializedReferralCode = referralCode;
            break;
        }
        catch (error) {
            if (isAlreadyExistsError(error) && attempt < maxReferralGenerationAttempts) {
                continue;
            }
            throw error;
        }
    }
    if (!initializedReferralCode) {
        throw new Error("Failed to initialize referral code for new user");
    }
    await trackAnalyticsEvent(user.uid, "user_registered", {
        authProvider,
        emailDomain: user.email?.split("@")[1] ?? null,
    });
    functions.logger.info("User profile document initialized", {
        userId: user.uid,
        referralCode: initializedReferralCode,
    });
});
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const failures = await runUserDeletionCleanup(userId);
    if (failures.length > 0) {
        await enqueueUserCleanupRetry(userId, failures);
        functions.logger.error("User deletion cleanup failed", { userId, failures });
        throw new Error(`User cleanup incomplete for ${userId}`);
    }
    await userDeletionCleanupQueueRef(userId).delete().catch(() => undefined);
    functions.logger.info("Deleted user and all associated data", { userId });
});
exports.trackLogin = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    (0, appCheck_1.assertCallableAppCheck)(context, "trackLogin");
    const userId = context.auth.uid;
    await (0, rateLimit_1.enforceRateLimit)({
        db,
        namespace: "track_login",
        userId,
        maxRequests: TRACK_LOGIN_RATE_LIMIT_MAX,
        windowMs: TRACK_LOGIN_RATE_LIMIT_WINDOW_MS,
        errorMessage: "Too many login tracking attempts. Please try again later.",
    });
    const platform = normalizedPlatform(data?.platform);
    const appVersion = normalizedAppVersion(data?.appVersion);
    await db.collection(constants_1.Collections.users).doc(userId).set({
        engagement: {
            loginCount: admin.firestore.FieldValue.increment(1),
            lastLoginDate: admin.firestore.FieldValue.serverTimestamp(),
        },
        metadata: {
            platform,
            appVersion,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
    }, { merge: true });
    return { success: true };
});
exports.recordAnalyticsEvent = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    (0, appCheck_1.assertCallableAppCheck)(context, "recordAnalyticsEvent");
    const userId = context.auth.uid;
    await (0, rateLimit_1.enforceRateLimit)({
        db,
        namespace: "analytics_event",
        userId,
        maxRequests: ANALYTICS_RATE_LIMIT_MAX,
        windowMs: ANALYTICS_RATE_LIMIT_WINDOW_MS,
        errorMessage: "Too many analytics events. Please try again later.",
    });
    const eventType = sanitizeAnalyticsEventType(data?.eventType);
    if (!eventType) {
        throw new functions.https.HttpsError("invalid-argument", "eventType is required");
    }
    const properties = sanitizeAnalyticsProperties(data?.properties);
    const platform = normalizedPlatform(data?.platform);
    const appVersion = normalizedAppVersion(data?.appVersion);
    await trackAnalyticsEvent(userId, eventType, properties, {
        platform,
        appVersion,
    });
    return { success: true };
});
exports.verifyUser = functions.https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    (0, appCheck_1.assertCallableAppCheck)(context, "verifyUser");
    const userId = context.auth.uid;
    await (0, rateLimit_1.enforceRateLimit)({
        db,
        namespace: "verify_user",
        userId,
        maxRequests: VERIFY_USER_RATE_LIMIT_MAX,
        windowMs: VERIFY_USER_RATE_LIMIT_WINDOW_MS,
        errorMessage: "Too many user verification attempts. Please try again later.",
    });
    const snapshot = await db.collection(constants_1.Collections.users).doc(userId).get();
    return { userId, hasProfile: snapshot.exists };
});
exports.pruneExpiredAnalyticsEvents = functions.pubsub
    .schedule("every 24 hours")
    .timeZone("Europe/London")
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const batchSize = 300;
    let totalDeleted = 0;
    while (true) {
        const expired = await db
            .collection(constants_1.Collections.analytics.root)
            .doc(constants_1.Collections.analytics.events)
            .collection(constants_1.Collections.analytics.items)
            .where("expiresAt", "<=", now)
            .limit(batchSize)
            .get();
        if (expired.empty)
            break;
        const batch = db.batch();
        for (const doc of expired.docs) {
            batch.delete(doc.ref);
        }
        await batch.commit();
        totalDeleted += expired.size;
        if (expired.size < batchSize)
            break;
    }
    functions.logger.info("Pruned expired analytics events", { totalDeleted });
    return null;
});
exports.retryFailedUserCleanup = functions.pubsub
    .schedule("every 24 hours")
    .timeZone("Europe/London")
    .onRun(async () => {
    const queueSnapshot = await db.collection(constants_1.Collections.ops.root)
        .doc(constants_1.Collections.ops.userDeletionCleanupQueue)
        .collection(constants_1.Collections.ops.items)
        .orderBy("updatedAt", "asc")
        .limit(25)
        .get();
    if (queueSnapshot.empty)
        return null;
    for (const queued of queueSnapshot.docs) {
        const claim = await db.runTransaction(async (transaction) => {
            const latest = await transaction.get(queued.ref);
            if (!latest.exists) {
                return { claimed: false, userId: queued.id };
            }
            const payload = latest.data() ?? {};
            const status = typeof payload.status == "string" ? payload.status : "pending";
            const userId = typeof payload.userId == "string" ? payload.userId : latest.id;
            const attempts = Number(payload.attempts ?? 0);
            if (status !== "pending") {
                return { claimed: false, userId };
            }
            if (attempts >= MAX_CLEANUP_RETRY_ATTEMPTS) {
                transaction.set(queued.ref, {
                    status: "failed_permanent",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                return { claimed: false, userId };
            }
            transaction.set(queued.ref, {
                status: "processing",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return { claimed: true, userId };
        });
        if (!claim.claimed) {
            continue;
        }
        const failures = await runUserDeletionCleanup(claim.userId);
        if (failures.length == 0) {
            await queued.ref.delete().catch(() => undefined);
            functions.logger.info("Resolved queued user deletion cleanup", { userId: claim.userId });
            continue;
        }
        await queued.ref.set({
            userId: claim.userId,
            failures: failures.slice(0, 20),
            attempts: admin.firestore.FieldValue.increment(1),
            status: "pending",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    return null;
});
//# sourceMappingURL=auth.js.map