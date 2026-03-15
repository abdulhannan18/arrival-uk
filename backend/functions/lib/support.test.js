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
const support_1 = require("./support");
(0, node_test_1.default)("normalizedPlatform accepts allowlisted values only", () => {
    strict_1.default.equal(support_1.__private__.normalizedPlatform("IOS"), "ios");
    strict_1.default.equal(support_1.__private__.normalizedPlatform("android"), "android");
    strict_1.default.equal(support_1.__private__.normalizedPlatform("desktop"), "unknown");
});
(0, node_test_1.default)("normalizedAppVersion enforces safe version format", () => {
    strict_1.default.equal(support_1.__private__.normalizedAppVersion("1.2.3"), "1.2.3");
    strict_1.default.equal(support_1.__private__.normalizedAppVersion(" 2_0-rc1 "), "2_0-rc1");
    strict_1.default.equal(support_1.__private__.normalizedAppVersion("bad version"), "unknown");
});
(0, node_test_1.default)("sanitizeSupportMetadata keeps only primitive values and caps entries", () => {
    const input = {};
    for (let index = 0; index < 30; index += 1) {
        input[`k${index}`] = index;
    }
    input.arrayValue = [1, 2, 3];
    input.objectValue = { nested: true };
    input.booleanValue = true;
    input.stringValue = "hello";
    const sanitized = support_1.__private__.sanitizeSupportMetadata(input);
    strict_1.default.ok(sanitized);
    strict_1.default.ok(Object.keys(sanitized).length <= 20);
    strict_1.default.equal(sanitized.arrayValue, undefined);
    strict_1.default.equal(sanitized.objectValue, undefined);
});
(0, node_test_1.default)("validateTicketID rejects invalid identifiers", () => {
    strict_1.default.equal(support_1.__private__.validateTicketID("abc123"), "abc123");
    strict_1.default.throws(() => support_1.__private__.validateTicketID("bad/id"), (error) => {
        if (!(error instanceof functions.https.HttpsError))
            return false;
        return error.code === "invalid-argument";
    });
    strict_1.default.throws(() => support_1.__private__.validateTicketID(""), (error) => {
        if (!(error instanceof functions.https.HttpsError))
            return false;
        return error.code === "invalid-argument";
    });
});
//# sourceMappingURL=support.test.js.map