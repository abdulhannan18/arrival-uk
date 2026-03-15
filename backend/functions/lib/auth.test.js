"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const auth_1 = require("./auth");
(0, node_test_1.default)("generateReferralCode returns expected shape", () => {
    const code = auth_1.__private__.generateReferralCode();
    strict_1.default.match(code, /^[0-9A-F]{12}$/);
});
(0, node_test_1.default)("generateReferralCode has high uniqueness across samples", () => {
    const samples = new Set();
    for (let index = 0; index < 512; index += 1) {
        samples.add(auth_1.__private__.generateReferralCode());
    }
    // Random collisions are possible but should remain rare in this sample size.
    strict_1.default.ok(samples.size > 500);
});
(0, node_test_1.default)("normalizedPlatform only accepts allowlisted values", () => {
    strict_1.default.equal(auth_1.__private__.normalizedPlatform("ios"), "ios");
    strict_1.default.equal(auth_1.__private__.normalizedPlatform("ANDROID"), "android");
    strict_1.default.equal(auth_1.__private__.normalizedPlatform("desktop"), "unknown");
    strict_1.default.equal(auth_1.__private__.normalizedPlatform(undefined), "unknown");
});
(0, node_test_1.default)("normalizedAppVersion enforces expected format", () => {
    strict_1.default.equal(auth_1.__private__.normalizedAppVersion("1.2.3"), "1.2.3");
    strict_1.default.equal(auth_1.__private__.normalizedAppVersion(" 2_0-rc1 "), "2_0-rc1");
    strict_1.default.equal(auth_1.__private__.normalizedAppVersion("1.0 beta"), "unknown");
    strict_1.default.equal(auth_1.__private__.normalizedAppVersion(undefined), "unknown");
});
(0, node_test_1.default)("sanitizeAnalyticsEventType enforces non-empty and max length", () => {
    strict_1.default.equal(auth_1.__private__.sanitizeAnalyticsEventType(" home_opened "), "home_opened");
    strict_1.default.equal(auth_1.__private__.sanitizeAnalyticsEventType(""), null);
    strict_1.default.equal(auth_1.__private__.sanitizeAnalyticsEventType(undefined), null);
    strict_1.default.equal(auth_1.__private__.sanitizeAnalyticsEventType("x".repeat(80))?.length, 64);
});
(0, node_test_1.default)("sanitizeAnalyticsProperties keeps only supported primitive values", () => {
    const sanitized = auth_1.__private__.sanitizeAnalyticsProperties({
        validString: "value",
        validBool: true,
        validNumber: 42,
        nested: { nope: true },
        list: [1, 2, 3],
        nil: null,
    });
    strict_1.default.deepEqual(sanitized, {
        validString: "value",
        validBool: true,
        validNumber: 42,
    });
});
//# sourceMappingURL=auth.test.js.map