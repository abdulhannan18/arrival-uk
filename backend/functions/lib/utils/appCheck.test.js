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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const functions = __importStar(require("firebase-functions"));
const appCheck_1 = require("./appCheck");
(0, node_test_1.default)("parseBooleanFlag accepts truthy string variants", () => {
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("true"), true);
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("1"), true);
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("yes"), true);
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("on"), true);
});
(0, node_test_1.default)("parseBooleanFlag rejects non-truthy values", () => {
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("false"), false);
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag("0"), false);
    strict_1.default.equal(appCheck_1.__private__.parseBooleanFlag(undefined), false);
});
(0, node_test_1.default)("assertCallableAppCheck allows emulators", () => {
    strict_1.default.doesNotThrow(() => (0, appCheck_1.assertCallableAppCheck)({ app: undefined, auth: undefined }, "trackLogin", { isEmulator: true, allowUnverified: false }));
});
(0, node_test_1.default)("assertCallableAppCheck allows explicitly unverified mode", () => {
    strict_1.default.doesNotThrow(() => (0, appCheck_1.assertCallableAppCheck)({ app: undefined, auth: undefined }, "trackLogin", { isEmulator: false, allowUnverified: true }));
});
(0, node_test_1.default)("assertCallableAppCheck rejects missing app attestation in production mode", () => {
    strict_1.default.throws(() => (0, appCheck_1.assertCallableAppCheck)({ app: undefined, auth: { uid: "user_123" } }, "trackLogin", { isEmulator: false, allowUnverified: false }), (error) => {
        if (!(error instanceof functions.https.HttpsError))
            return false;
        return error.code === "failed-precondition";
    });
});
(0, node_test_1.default)("assertCallableAppCheck passes when app check payload exists", () => {
    strict_1.default.doesNotThrow(() => (0, appCheck_1.assertCallableAppCheck)({
        app: { appId: "1:1234567890:ios:test", token: {} },
        auth: undefined,
    }, "trackLogin", { isEmulator: false, allowUnverified: false }));
});
(0, node_test_1.default)("isUnsafeBypassConfiguration flags non-emulator bypass in production-like runtime", () => {
    strict_1.default.equal(appCheck_1.__private__.isUnsafeBypassConfiguration({
        isEmulator: false,
        allowUnverified: true,
        nodeEnv: "production",
    }), true);
    strict_1.default.equal(appCheck_1.__private__.isUnsafeBypassConfiguration({
        isEmulator: true,
        allowUnverified: true,
        nodeEnv: "development",
    }), false);
});
(0, node_test_1.default)("assertSafeBypassConfiguration throws when bypass is enabled outside emulator", () => {
    strict_1.default.throws(() => appCheck_1.__private__.assertSafeBypassConfiguration({
        isEmulator: false,
        allowUnverified: true,
        nodeEnv: "development",
    }));
});
//# sourceMappingURL=appCheck.test.js.map