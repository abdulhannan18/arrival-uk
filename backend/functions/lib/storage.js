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
exports.cleanupUserStorage = exports.processProfilePicture = exports.__private__ = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const crypto_1 = require("crypto");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const storage = admin.storage();
const ALLOWED_IMAGE_CONTENT_TYPES = new Set([
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
]);
const LOG_PSEUDONYMIZATION_KEY = "LOG_PSEUDONYMIZATION_KEY";
function isProfileImagePath(filePath) {
    if (!filePath)
        return false;
    // Ownership is enforced by Firebase Storage Security Rules:
    // users/{uid}/profile/** writable only by the authenticated owner uid.
    return /users\/[^/]+\/profile\/.+/.test(filePath);
}
function isImageContentType(contentType) {
    if (!contentType)
        return false;
    const normalized = contentType
        .split(";")[0]
        .trim()
        .toLowerCase();
    return ALLOWED_IMAGE_CONTENT_TYPES.has(normalized);
}
function logPseudonymizationKey() {
    return (process.env.LOG_PSEUDONYMIZATION_KEY ||
        functions.config()?.logging?.pseudonymization_key ||
        LOG_PSEUDONYMIZATION_KEY);
}
function pseudonymizeLogIdentifier(prefix, value) {
    if (typeof value !== "string")
        return undefined;
    const normalized = value.trim();
    if (!normalized)
        return undefined;
    const digest = (0, crypto_1.createHmac)("sha256", logPseudonymizationKey()).update(normalized).digest("hex");
    return `${prefix}:${digest.slice(0, 12)}`;
}
exports.__private__ = {
    pseudonymizeLogIdentifier,
};
/**
 * Lightweight storage hook:
 * - validates profile image path/content type
 * - normalizes cache metadata
 *
 * Note: Image resizing pipeline is intentionally left off by default to avoid
 * hard runtime dependency on native image libraries. Add sharp/imagemagick in
 * a dedicated rollout if needed.
 */
exports.processProfilePicture = functions.storage.object().onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;
    const bucketName = object.bucket;
    if (!filePath || !isProfileImagePath(filePath) || !isImageContentType(contentType) || !bucketName) {
        return;
    }
    try {
        const bucket = storage.bucket(bucketName);
        const file = bucket.file(filePath);
        await file.setMetadata({
            contentType: contentType,
            cacheControl: "private, max-age=3600",
            metadata: {
                processedBy: "processProfilePicture",
                processedAt: new Date().toISOString(),
            },
        });
        functions.logger.info("Profile image metadata normalized", {
            fileRef: pseudonymizeLogIdentifier("file", filePath),
        });
    }
    catch (error) {
        functions.logger.error("Failed to process profile image", {
            fileRef: pseudonymizeLogIdentifier("file", filePath),
            error: error instanceof Error ? error.message : "unknown_error",
        });
    }
});
/**
 * Cleanup storage when auth user is removed.
 */
exports.cleanupUserStorage = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const bucket = storage.bucket();
    const deleteBatchSize = 50;
    try {
        const [files] = await bucket.getFiles({
            prefix: `users/${userId}/`,
        });
        if (files.length === 0) {
            functions.logger.info("No storage files found for deleted user", {
                userRef: pseudonymizeLogIdentifier("uid", userId),
            });
            return;
        }
        let deletedCount = 0;
        let failedCount = 0;
        for (let index = 0; index < files.length; index += deleteBatchSize) {
            const batch = files.slice(index, index + deleteBatchSize);
            const results = await Promise.allSettled(batch.map((file) => file.delete({ ignoreNotFound: true })));
            for (const result of results) {
                if (result.status === "fulfilled") {
                    deletedCount += 1;
                }
                else {
                    failedCount += 1;
                    functions.logger.warn("User storage file delete failed", {
                        userRef: pseudonymizeLogIdentifier("uid", userId),
                        error: result.reason instanceof Error ? result.reason.message : "unknown_error",
                    });
                }
            }
        }
        if (failedCount > 0) {
            functions.logger.warn("Deleted user storage with partial failures", {
                userRef: pseudonymizeLogIdentifier("uid", userId),
                deletedCount,
                failedCount,
                totalCount: files.length,
            });
        }
        else {
            functions.logger.info("Deleted storage files for user", {
                userRef: pseudonymizeLogIdentifier("uid", userId),
                count: deletedCount,
            });
        }
    }
    catch (error) {
        functions.logger.error("Failed to cleanup user storage", {
            userRef: pseudonymizeLogIdentifier("uid", userId),
            error: error instanceof Error ? error.message : "unknown_error",
        });
    }
});
//# sourceMappingURL=storage.js.map