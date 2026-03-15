import test from "node:test";
import assert from "node:assert/strict";
import { invalidatePrivilegedCallerCache, isPrivilegedCaller } from "./privileged";

type FakeDoc = { exists: boolean };

type FakeDB = {
  collection: (name: string) => {
    doc: (id: string) => {
      get: () => Promise<FakeDoc>;
    };
  };
};

function makeContext(uid?: string): { auth?: { uid: string } } {
  if (!uid) return {};
  return { auth: { uid } };
}

function makeDB(resolver: (path: string) => FakeDoc): FakeDB {
  return {
    collection(name: string) {
      return {
        doc(id: string) {
          return {
            async get() {
              return resolver(`${name}/${id}`);
            },
          };
        },
      };
    },
  };
}

test("isPrivilegedCaller rejects unauthenticated calls", async () => {
  const db = makeDB(() => ({ exists: true }));
  const result = await isPrivilegedCaller(
    makeContext() as never,
    db as never
  );
  assert.equal(result, false);
});

test("isPrivilegedCaller returns true when admin doc exists", async () => {
  const userId = "admin-user";
  invalidatePrivilegedCallerCache(userId);

  const db = makeDB((path) => ({ exists: path === `admins/${userId}` }));
  const result = await isPrivilegedCaller(
    makeContext(userId) as never,
    db as never
  );

  assert.equal(result, true);
  invalidatePrivilegedCallerCache(userId);
});

test("isPrivilegedCaller caches lookup results", async () => {
  const userId = "cached-user";
  invalidatePrivilegedCallerCache(userId);

  let reads = 0;
  const db = makeDB(() => {
    reads += 1;
    return { exists: true };
  });

  const first = await isPrivilegedCaller(
    makeContext(userId) as never,
    db as never
  );
  const second = await isPrivilegedCaller(
    makeContext(userId) as never,
    db as never
  );

  assert.equal(first, true);
  assert.equal(second, true);
  assert.equal(reads, 1);

  invalidatePrivilegedCallerCache(userId);
});
