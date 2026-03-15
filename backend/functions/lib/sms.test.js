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
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const functions = __importStar(require("firebase-functions"));
const sms_1 = require("./sms");
(0, node_test_1.default)("isValidE164Phone validates E.164 format", () => {
    strict_1.default.equal(sms_1.__private__.isValidE164Phone("+447911123456"), true);
    strict_1.default.equal(sms_1.__private__.isValidE164Phone("07911123456"), false);
    strict_1.default.equal(sms_1.__private__.isValidE164Phone("+1"), false);
});
(0, node_test_1.default)("sendSMSReminderImpl rejects invalid E.164 phone numbers", async () => {
    await strict_1.default.rejects(sms_1.__private__.sendSMSReminderImpl({ phoneNumber: "07911123456", message: "Hello" }, { auth: { uid: "user_1" } }, {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => undefined,
        getTwilioClient: () => ({
            messages: {
                create: async () => ({ sid: "sid_1" }),
            },
        }),
        fromPhone: () => "+447000000001",
    }), (error) => {
        const typed = error;
        return typed.code === "invalid-argument";
    });
});
(0, node_test_1.default)("redactPhone keeps only final 4 digits", () => {
    strict_1.default.equal(sms_1.__private__.redactPhone("+447911123456"), "***3456");
    strict_1.default.equal(sms_1.__private__.redactPhone("+1234"), "***");
});
(0, node_test_1.default)("sendSMSReminderImpl returns failed-precondition when Twilio is not configured", async () => {
    await strict_1.default.rejects(sms_1.__private__.sendSMSReminderImpl({ phoneNumber: "+447911123456", message: "Hello" }, { auth: { uid: "user_2" } }, {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => undefined,
        getTwilioClient: () => null,
        fromPhone: () => null,
    }), (error) => {
        const typed = error;
        return typed.code === "failed-precondition";
    });
});
(0, node_test_1.default)("sendSMSReminderImpl propagates rate-limit failures", async () => {
    await strict_1.default.rejects(sms_1.__private__.sendSMSReminderImpl({ phoneNumber: "+447911123456", message: "Hello" }, { auth: { uid: "user_3" } }, {
        assertCallableAppCheck: () => undefined,
        isPrivilegedCaller: async () => true,
        enforceRateLimit: async () => {
            throw new functions.https.HttpsError("resource-exhausted", "Rate limit exceeded for SMS sending.");
        },
        getTwilioClient: () => ({
            messages: {
                create: async () => ({ sid: "sid_2" }),
            },
        }),
        fromPhone: () => "+447000000002",
    }), (error) => {
        const typed = error;
        return typed.code === "resource-exhausted";
    });
});
//# sourceMappingURL=sms.test.js.map