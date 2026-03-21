import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

const projectID = "arrivaluk-firestore-rules";
const rules = readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8");

let testEnv: RulesTestEnvironment;

type UserDocument = {
  profile: {
    university: string | null;
    course: string | null;
    studyLevel: string | null;
    city: string | null;
    arrivalDate: Date | null;
    nationality: string | null;
    homeCurrency: string | null;
    accommodationType: string | null;
    visaType: string | null;
  };
  preferences: {
    language: string;
    notifications: {
      taskReminders: boolean;
      weeklyDigest: boolean;
      productUpdates: boolean;
    };
    privacy: {
      allowAnalytics: boolean;
      allowPersonalizedAds: boolean;
      dataSharing: boolean;
    };
  };
  progress: {
    completedTasks: string[];
    totalTasks: number;
    completionRate: number;
    lastActivityDate: Date | null;
  };
};

function makeValidUserDocument(overrides: Partial<UserDocument> = {}): UserDocument {
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

function makeValidDeviceDocument(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    fcmToken: "fcm_token_123",
    platform: "ios",
    appVersion: "1.2.3",
    updatedAt: new Date("2026-03-20T00:00:00.000Z"),
    createdAt: new Date("2026-03-19T00:00:00.000Z"),
    ...overrides,
  };
}

function makeValidContentTaskDocument(overrides: Record<string, unknown> = {}): Record<string, unknown> {
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

function makeValidAnalyticsEventDocument(overrides: Record<string, unknown> = {}): Record<string, unknown> {
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

function makeValidFeaturedPartnershipDocument(overrides: Record<string, unknown> = {}): Record<string, unknown> {
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

function makeValidFeatureFlagsDocument(): Record<string, unknown> {
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
    await setDoc(doc(db, "users/user_123"), makeValidUserDocument());
    await setDoc(doc(db, "users/user_456"), makeValidUserDocument({
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
    await setDoc(doc(db, "admins/admin_123"), {
      createdAt: new Date("2026-03-20T00:00:00.000Z"),
    });
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: projectID,
    firestore: { rules },
  });
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedBaselineDocuments();
});

test.after(async () => {
  await testEnv.cleanup();
});

test("authenticated user reading own document is allowed", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertSucceeds(getDoc(doc(db, "users/user_123")));
});

test("authenticated user reading another user's document is denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(getDoc(doc(db, "users/user_456")));
});

test("unauthenticated read is denied", async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "users/user_123")));
});

test("admin can read any user document", async () => {
  const snapshot = await assertSucceeds(getDoc(doc(adminDb(), "users/user_456")));
  assert.equal(snapshot.data()?.profile?.city, "Manchester");
});

test("client cannot write admin-only root fields", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(updateDoc(doc(db, "users/user_123"), {
    role: "admin",
  }));
});

test("write with missing required preference fields is denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(updateDoc(doc(db, "users/user_123"), {
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

test("device write with missing field denied", async () => {
  const payload = makeValidDeviceDocument();
  delete payload.updatedAt;
  await assertFails(setDoc(
    doc(adminDb(), "users/user_123/devices/device_123"),
    payload
  ));
});

test("device write with invalid platform denied", async () => {
  await assertFails(setDoc(
    doc(adminDb(), "users/user_123/devices/device_123"),
    makeValidDeviceDocument({ platform: "desktop" })
  ));
});

test("content write with valid shape allowed", async () => {
  await assertSucceeds(setDoc(
    doc(adminDb(), "content/tasks/items/task_123"),
    makeValidContentTaskDocument()
  ));
});

test("content write with extra arbitrary field denied", async () => {
  await assertFails(setDoc(
    doc(adminDb(), "content/tasks/items/task_123"),
    makeValidContentTaskDocument({ unexpectedField: true })
  ));
});

test("admin write without claim denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(setDoc(
    doc(db, "config/featureFlags"),
    makeValidFeatureFlagsDocument()
  ));
});

test("admin write with claim and valid shape allowed", async () => {
  await assertSucceeds(setDoc(
    doc(adminDb(), "config/featureFlags"),
    makeValidFeatureFlagsDocument()
  ));
});

test("analytics write without claim denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(setDoc(
    doc(db, "analytics/events/items/event_123"),
    makeValidAnalyticsEventDocument()
  ));
});

test("analytics write with claim and valid shape allowed", async () => {
  await assertSucceeds(setDoc(
    doc(adminDb(), "analytics/events/items/event_123"),
    makeValidAnalyticsEventDocument()
  ));
});

test("partnership write without claim denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(setDoc(
    doc(db, "partnerships/featured/items/partner_123"),
    makeValidFeaturedPartnershipDocument()
  ));
});

test("partnership write with claim and valid shape allowed", async () => {
  await assertSucceeds(setDoc(
    doc(adminDb(), "partnerships/featured/items/partner_123"),
    makeValidFeaturedPartnershipDocument()
  ));
});

test("config write without claim denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(setDoc(
    doc(db, "config/featureFlags"),
    makeValidFeatureFlagsDocument()
  ));
});

test("config write with claim and valid shape allowed", async () => {
  await assertSucceeds(setDoc(
    doc(adminDb(), "config/featureFlags"),
    makeValidFeatureFlagsDocument()
  ));
});

test("notification dead letter write without claim denied", async () => {
  const db = testEnv.authenticatedContext("user_123").firestore();
  await assertFails(setDoc(doc(db, "notificationDeadLetter/notif_123"), {
    notificationId: "notif_123",
  }));
});

test("notification dead letter admin read allowed", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "notificationDeadLetter/notif_123"), {
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

  const snapshot = await assertSucceeds(getDoc(doc(adminDb(), "notificationDeadLetter/notif_123")));
  assert.equal(snapshot.data()?.notificationType, "task_reminder");
});
