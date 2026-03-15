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
exports.assertCallableAppCheck = assertCallableAppCheck;
const functions = __importStar(require("firebase-functions"));
function parseBooleanFlag(value) {
    if (typeof value !== "string")
        return false;
    const normalized = value.trim().toLowerCase();
    return normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on";
}
function isUnsafeBypassConfiguration(policy) {
    const normalizedNodeEnv = policy.nodeEnv.trim().toLowerCase();
    const isProductionNodeEnv = normalizedNodeEnv === "production";
    return policy.allowUnverified && (isProductionNodeEnv || !policy.isEmulator);
}
function assertSafeBypassConfiguration(policy) {
    if (!isUnsafeBypassConfiguration(policy))
        return;
    functions.logger.error("unsafe_app_check_bypass_configuration", {
        nodeEnv: policy.nodeEnv || "unknown",
        isEmulator: policy.isEmulator,
    });
    throw new Error("ALLOW_UNVERIFIED_APPCHECK/security.allow_unverified_app_check must never be enabled outside emulator mode");
}
function resolvedPolicy(override) {
    const configAllowUnverified = parseBooleanFlag(functions.config()?.security?.allow_unverified_app_check);
    return {
        isEmulator: override?.isEmulator ?? process.env.FUNCTIONS_EMULATOR === "true",
        allowUnverified: override?.allowUnverified
            ?? (parseBooleanFlag(process.env.ALLOW_UNVERIFIED_APPCHECK) || configAllowUnverified),
    };
}
function assertCallableAppCheck(context, callableName, override) {
    const policy = resolvedPolicy(override);
    if (!override) {
        assertSafeBypassConfiguration({
            isEmulator: policy.isEmulator,
            allowUnverified: policy.allowUnverified,
            nodeEnv: process.env.NODE_ENV ?? "",
        });
    }
    if (policy.isEmulator || policy.allowUnverified)
        return;
    if (!context.app) {
        functions.logger.warn("callable_missing_app_check", {
            callable: callableName,
            userId: context.auth?.uid ?? null,
        });
        throw new functions.https.HttpsError("failed-precondition", "A valid App Check token is required.");
    }
}
assertSafeBypassConfiguration({
    ...resolvedPolicy(),
    nodeEnv: process.env.NODE_ENV ?? "",
});
exports.__private__ = {
    parseBooleanFlag,
    resolvedPolicy,
    isUnsafeBypassConfiguration,
    assertSafeBypassConfiguration,
};
//# sourceMappingURL=appCheck.js.map