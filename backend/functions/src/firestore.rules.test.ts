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
  const db = testEnv.authenticatedContext("admin_123").firestore();
  const snapshot = await assertSucceeds(getDoc(doc(db, "users/user_456")));
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
