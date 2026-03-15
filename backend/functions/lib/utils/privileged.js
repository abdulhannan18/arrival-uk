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
exports.isPrivilegedCaller = isPrivilegedCaller;
exports.invalidatePrivilegedCallerCache = invalidatePrivilegedCallerCache;
const functions = __importStar(require("firebase-functions"));
const privilegedCache = new Map();
const cacheTTLms = 30 * 1000;
async function isPrivilegedCaller(context, db) {
    const userId = context.auth?.uid;
    if (!userId)
        return false;
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
    }
    catch (error) {
        functions.logger.warn("privileged_check_failed", {
            userId,
            error: error instanceof Error ? error.message : "unknown_error",
        });
        return false;
    }
}
function invalidatePrivilegedCallerCache(userId) {
    privilegedCache.delete(userId);
}
//# sourceMappingURL=privileged.js.map