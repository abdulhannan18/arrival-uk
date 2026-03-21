"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const storage_1 = require("./storage");
(0, node_test_1.default)("pseudonymizeLogIdentifier does not contain raw storage identifiers", () => {
    const previous = process.env.LOG_PSEUDONYMIZATION_KEY;
    process.env.LOG_PSEUDONYMIZATION_KEY = "storage-log-test-key";
    try {
        const userRef = storage_1.__private__.pseudonymizeLogIdentifier("uid", "user-123");
        const fileRef = storage_1.__private__.pseudonymizeLogIdentifier("file", "users/user-123/profile/avatar.png");
        strict_1.default.ok(userRef?.startsWith("uid:"));
        strict_1.default.ok(fileRef?.startsWith("file:"));
        strict_1.default.ok(!userRef?.includes("user-123"));
        strict_1.default.ok(!fileRef?.includes("user-123"));
        strict_1.default.ok(!fileRef?.includes("avatar.png"));
    }
    finally {
        if (previous === undefined) {
            delete process.env.LOG_PSEUDONYMIZATION_KEY;
        }
        else {
            process.env.LOG_PSEUDONYMIZATION_KEY = previous;
        }
    }
});
//# sourceMappingURL=storage.test.js.map