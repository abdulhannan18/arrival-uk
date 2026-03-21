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
function makeValidDeviceDocument(overrides = {}) {
    return {
        fcmToken: "fcm_token_123",
        platform: "ios",
        appVersion: "1.2.3",
        updatedAt: new Date("2026-03-20T00:00:00.000Z"),
        createdAt: new Date("2026-03-19T00:00:00.000Z"),
        ...overrides,
    };
}
function makeValidContentTaskDocument(overrides = {}) {
    return {
        id: "task_123",
        categoryId: "before_arrival",
        title: "Confirm visa documents are complete",
        detail: "Double-check passport validity and funding documents.",
        timing: "month_before_arrival",
        priority: "must_do",
        isPublished: true,
        version: 1,
        order: 1,
        sourceTitle: "GOV.UK",
        sourceURL: "https://www.gov.uk/student-visa",
        ...overrides,
    };
}
function makeValidAnalyticsEventDocument(overrides = {}) {
    return {
        userId: "user_123",
        eventType: "user_registered",
        properties: {
            authProvider: "google",
        },
        platform: "backend",
        appVersion: "cloud_function",
        timestamp: new Date("2026-03-20T00:00:00.000Z"),
        expiresAt: new Date("2026-09-20T00:00:00.000Z"),
        ...overrides,
    };
}
function makeValidFeaturedPartnershipDocument(overrides = {}) {
    return {
        id: "partner_123",
        category: "banking",
        title: "Student Bank Bundle",
        subtitle: "Discounted banking partner",
        ctaTitle: "Open now",
        destinationURL: "https://partner.example.com/open",
        isPublished: true,
        order: 1,
        updatedAt: new Date("2026-03-20T00:00:00.000Z"),
        ...overrides,
    };
}
function makeValidFeatureFlagsDocument() {
    return {
        phase_3_config: {
            swipe_threshold: 160,
            spring_damping: 0.8,
            hero_card_limit: 1,
            critical_urgency_threshold: 0.8,
        },
        phase_4_wallet: {
            required_docs: ["passport", "brp", "university_cas"],
            biometric_enforced: true,
        },
        phase_14_marketplace: {
            identity_token_ttl_seconds: 600,
            providers: [],
        },
        phase_15_global: {
            active_region: "uk",
            fallback_region: "uk",
            regions: [
                {
                    region: "uk",
                },
            ],
        },
    };
}
function adminDb() {
    return testEnv.authenticatedContext("admin_123", { admin: true }).firestore();
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
    const snapshot = await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.getDoc)((0, firestore_1.doc)(adminDb(), "users/user_456")));
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
(0, node_test_1.default)("device write with missing field denied", async () => {
    const payload = makeValidDeviceDocument();
    delete payload.updatedAt;
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "users/user_123/devices/device_123"), payload));
});
(0, node_test_1.default)("device write with invalid platform denied", async () => {
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "users/user_123/devices/device_123"), makeValidDeviceDocument({ platform: "desktop" })));
});
(0, node_test_1.default)("content write with valid shape allowed", async () => {
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "content/tasks/items/task_123"), makeValidContentTaskDocument()));
});
(0, node_test_1.default)("content write with extra arbitrary field denied", async () => {
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "content/tasks/items/task_123"), makeValidContentTaskDocument({ unexpectedField: true })));
});
(0, node_test_1.default)("admin write without claim denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(db, "config/featureFlags"), makeValidFeatureFlagsDocument()));
});
(0, node_test_1.default)("admin write with claim and valid shape allowed", async () => {
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "config/featureFlags"), makeValidFeatureFlagsDocument()));
});
(0, node_test_1.default)("analytics write without claim denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(db, "analytics/events/items/event_123"), makeValidAnalyticsEventDocument()));
});
(0, node_test_1.default)("analytics write with claim and valid shape allowed", async () => {
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "analytics/events/items/event_123"), makeValidAnalyticsEventDocument()));
});
(0, node_test_1.default)("partnership write without claim denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(db, "partnerships/featured/items/partner_123"), makeValidFeaturedPartnershipDocument()));
});
(0, node_test_1.default)("partnership write with claim and valid shape allowed", async () => {
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "partnerships/featured/items/partner_123"), makeValidFeaturedPartnershipDocument()));
});
(0, node_test_1.default)("config write without claim denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(db, "config/featureFlags"), makeValidFeatureFlagsDocument()));
});
(0, node_test_1.default)("config write with claim and valid shape allowed", async () => {
    await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.setDoc)((0, firestore_1.doc)(adminDb(), "config/featureFlags"), makeValidFeatureFlagsDocument()));
});
(0, node_test_1.default)("notification dead letter write without claim denied", async () => {
    const db = testEnv.authenticatedContext("user_123").firestore();
    await (0, rules_unit_testing_1.assertFails)((0, firestore_1.setDoc)((0, firestore_1.doc)(db, "notificationDeadLetter/notif_123"), {
        notificationId: "notif_123",
    }));
});
(0, node_test_1.default)("notification dead letter admin read allowed", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
        await (0, firestore_1.setDoc)((0, firestore_1.doc)(context.firestore(), "notificationDeadLetter/notif_123"), {
            notificationId: "notif_123",
            userId: "uid:abcdef123456",
            notificationType: "task_reminder",
            channel: "push",
            failureReason: "messaging/internal-error",
            failureCode: "messaging/internal-error",
            attemptCount: 5,
            firstAttemptAt: new Date("2026-03-20T09:00:00.000Z"),
            lastAttemptAt: new Date("2026-03-20T12:00:00.000Z"),
            deadLetteredAt: new Date("2026-03-20T12:00:00.000Z"),
            payload: {
                type: "task_reminder",
                title: "Task reminder",
                body: "Bring your passport.",
                data: { type: "task_reminder", taskId: "task_123" },
            },
        });
    });
    const snapshot = await (0, rules_unit_testing_1.assertSucceeds)((0, firestore_1.getDoc)((0, firestore_1.doc)(adminDb(), "notificationDeadLetter/notif_123")));
    strict_1.default.equal(snapshot.data()?.notificationType, "task_reminder");
});
//# sourceMappingURL=firestore.rules.test.js.map