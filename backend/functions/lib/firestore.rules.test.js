"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const node_fs_1 = require("node:fs");
const node_path_1 = require("node:path");
const rules_unit_testing_1 = require("@firebase/rules-unit-testing");
const firestore_1 = require("firebase/firestore");
const projectID = "arrivaluk-firestore-rules";
const rules = (0, node_fs_1.readFileSync)((0, node_path_1.resolve)(__dirname, "../../firestore.rules"), "utf8");
let testEnv;
function makeValidUserDocument(overrides = {}) {
    return {
        profile: {
            university: "University of Leeds",
            course: "Computer Science",
            studyLevel: "Undergraduate",
            city: "Leeds",
            arrivalDate: new Date("2026-09-01T00:00:00.000Z"),
            nationality: "PK",
            homeCurrency: "PKR",
            accommodationType: "Private",
            visaType: "Student",
            ...overrides.profile,
        },
        preferences: {
            language: "en",
            notifications: {
                taskReminders: true,
                weeklyDigest: true,
                productUpdates: false,
            },
            privacy: {
                allowAnalytics: true,
                allowPersonalizedAds: false,
                dataSharing: false,
            },
            ...overrides.preferences,
        },
        progress: {
            completedTasks: ["task_1"],
            totalTasks: 3,
            completionRate: 33.3,
            lastActivityDate: new Date("2026-03-20T00:00:00.000Z"),
            ...overrides.progress,
        },
    };
}
async function seedBaselineDocuments() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await (0, firestore_1.setDoc)((0, firestore_1.doc)(db, "users/user_123"), makeValidUserDocument());
        await (0, firestore_1.setDoc)((0, firestore_1.doc)(db, "users/user_456"), makeValidUserDocument({
            profile: {
                university: "University of Manchester",
                course: "Business",
                studyLevel: "Postgraduate",
                city: "Manchester",
                arrivalDate: new Date("2026-09-10T00:00:00.000Z"),
                nationality: "IN",
                homeCurrency: "INR",
                accommodationType: "University",
                visaType: "Student",
            },
        }));
        await (0, firestore_1.setDoc)((0, firestore_1.doc)(db, "admins/admin_123"), {
            createdAt: new Date("2026-03-20T00:00:00.000Z"),
        });
    });
}
node_test_1.default.before(async () => {
    testEnv = await (0, rules_unit_testing_1.initializeTestEnvironment)({
        projectId: projectID,
        firestore: { rules },
    });
});
node_test_1.default.beforeEach(async () => {
    await testEnv.clearFirestore();
    await seedBaselineDocuments();
});
node_test_1.default.after(async () => {
    await testEnv.cleanup();
});
(0, node_test_1.default)("authenticated user reading own document is allowed", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.getDoc)((0, firestore_1.doc)(db, "users/user_123")));
});
(0, node_test_1.default)("authenticated user reading another user's document is denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.getDoc)((0, firestore_1.doc)(db, "users/user_456")));
});
(0, node_test_1.default)("unauthenticated read is denied", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.getDoc)((0, firestore_1.doc)(db, "users/user_123")));
});
(0, node_test_1.default)("admin can read any user document", async () => {
    const db = testEnv.authenticatedContext("admin_123").firestore();
    const snapshot = await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.getDoc)((0, firestore_1.doc)(db, "users/user_456")));
    strict_1.default.equal(snapshot.data()?.profile?.city, "Manchester");
});
(0, node_test_1.default)("client cannot write admin-only root fields", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.updateDoc)((0, firestore_1.doc)(db, "users/user_123"), {
        role: "admin",
    }));
});
(0, node_test_1.default)("write with missing required preference fields is denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.updateDoc)((0, firestore_1.doc)(db, "users/user_123"), {
        preferences: {
            language: "en",
            privacy: {
                allowAnalytics: true,
                allowPersonalizedAds: false,
                dataSharing: false,
            },
        },
    }));
});
//# sourceMappingURL=firestore.rules.test.js.map