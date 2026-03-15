import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

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

function isProfileImagePath(filePath?: string): boolean {
  if (!filePath) return false;
  // Ownership is enforced by Firebase Storage Security Rules:
  // users/{uid}/profile/** writable only by the authenticated owner uid.
  return /users\/[^/]+\/profile\/.+/.test(filePath);
}

function isImageContentType(contentType?: string): boolean {
  if (!contentType) return false;
  const normalized = contentType
    .split(";")[0]
    .trim()
    .toLowerCase();
  return ALLOWED_IMAGE_CONTENT_TYPES.has(normalized);
}

/**
 * Lightweight storage hook:
 * - validates profile image path/content type
 * - normalizes cache metadata
 *
 * Note: Image resizing pipeline is intentionally left off by default to avoid
 * hard runtime dependency on native image libraries. Add sharp/imagemagick in
 * a dedicated rollout if needed.
 */
export const processProfilePicture = functions.storage.object().onFinalize(async (object) => {
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

    functions.logger.info("Profile image metadata normalized", { filePath });
  } catch (error) {
    functions.logger.error("Failed to process profile image", {
      filePath,
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});

/**
 * Cleanup storage when auth user is removed.
 */
export const cleanupUserStorage = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const bucket = storage.bucket();
  const deleteBatchSize = 50;

  try {
    const [files] = await bucket.getFiles({
      prefix: `users/${userId}/`,
    });

    if (files.length === 0) {
      functions.logger.info("No storage files found for deleted user", { userId });
      return;
    }

    let deletedCount = 0;
    let failedCount = 0;

    for (let index = 0; index < files.length; index += deleteBatchSize) {
      const batch = files.slice(index, index + deleteBatchSize);
      const results = await Promise.allSettled(
        batch.map((file) => file.delete({ ignoreNotFound: true }))
      );

      for (const result of results) {
        if (result.status === "fulfilled") {
          deletedCount += 1;
        } else {
          failedCount += 1;
          functions.logger.warn("User storage file delete failed", {
            userId,
            error: result.reason instanceof Error ? result.reason.message : "unknown_error",
          });
        }
      }
    }

    if (failedCount > 0) {
      functions.logger.warn("Deleted user storage with partial failures", {
        userId,
        deletedCount,
        failedCount,
        totalCount: files.length,
      });
    } else {
      functions.logger.info("Deleted storage files for user", {
        userId,
        count: deletedCount,
      });
    }
  } catch (error) {
    functions.logger.error("Failed to cleanup user storage", {
      userId,
      error: error instanceof Error ? error.message : "unknown_error",
    });
  }
});
