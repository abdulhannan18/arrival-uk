import assert from "node:assert/strict";
import test from "node:test";
import { __private__ } from "./taskSync";

function makeOperation(overrides: Partial<{
  clientId: string;
  deviceId: string;
  operationId: string;
  entityId: string;
  entityVersion: number;
  title: string;
  categoryID: string;
  isCompleted: boolean;
  phase: number;
  updatedAt: string;
}> = {}) {
  const clientId = overrides.clientId ?? "client_1";
  const deviceId = overrides.deviceId ?? "device_1";
  const operationId = overrides.operationId ?? "op_1";
  const entityId = overrides.entityId ?? "task_1";
  const entityVersion = overrides.entityVersion ?? 1;
  const title = overrides.title ?? "Open bank account";
  const categoryID = overrides.categoryID ?? "banking";
  const isCompleted = overrides.isCompleted ?? true;
  const phase = overrides.phase ?? 1;
  const updatedAt = overrides.updatedAt ?? "2026-03-19T10:00:00.000Z";

  return {
    clientId,
    deviceId,
    operationId,
    operationType: "upsert_task",
    entityId,
    entityVersion,
    payload: {
      id: entityId,
      title,
      categoryID,
      isCompleted,
      phase,
      version: entityVersion,
      updatedAt,
    },
    timestamp: updatedAt,
  };
}

test("same operationId from same client returns the cached response without reapplying", () => {
  const operation = makeOperation();
  const serverTimestamp = new Date("2026-03-19T10:05:00.000Z");

  const first = __private__.processOperation(operation, serverTimestamp);
  const replay = __private__.processOperation(
    operation,
    new Date("2026-03-19T10:06:00.000Z"),
    undefined,
    { statusCode: first.statusCode, result: first.result }
  );

  assert.equal(first.statusCode, 200);
  assert.equal(replay.statusCode, 200);
  assert.deepEqual(replay.result, first.result);
});

test("stale versions are rejected with precondition failed and server state", () => {
  const operation = makeOperation({ entityVersion: 1, title: "Local draft" });
  const existing = {
    id: "task_1",
    title: "Server truth",
    categoryID: "banking",
    isCompleted: true,
    phase: 1,
    version: 3,
    updatedAt: "2026-03-19T10:04:00.000Z",
  };

  const outcome = __private__.processOperation(
    operation,
    new Date("2026-03-19T10:05:00.000Z"),
    existing
  );

  assert.equal(outcome.statusCode, 412);
  assert.equal(outcome.result.accepted, false);
  assert.equal(outcome.result.serverVersion, 3);
  assert.deepEqual(outcome.result.conflictPayload, existing);
});

test("same version with different payload yields a conflict", () => {
  const operation = makeOperation({ entityVersion: 2, title: "Local edit" });
  const existing = {
    id: "task_1",
    title: "Remote edit",
    categoryID: "banking",
    isCompleted: true,
    phase: 1,
    version: 2,
    updatedAt: "2026-03-19T10:04:00.000Z",
  };

  const outcome = __private__.processOperation(
    operation,
    new Date("2026-03-19T10:05:00.000Z"),
    existing
  );

  assert.equal(outcome.statusCode, 409);
  assert.equal(outcome.result.accepted, false);
  assert.deepEqual(outcome.result.conflictPayload, existing);
});

test("batch parsing rejects requests containing any invalid operation", () => {
  const parsed = __private__.parseBatchRequest({
    clientId: "client_1",
    deviceId: "device_1",
    sentAt: "2026-03-19T10:00:00.000Z",
    operations: [
      makeOperation(),
      {
        clientId: "client_1",
        deviceId: "device_1",
        operationId: "",
        operationType: "upsert_task",
        entityId: "task_2",
        entityVersion: 2,
        payload: {
          id: "task_2",
          title: "Invalid",
          categoryID: "banking",
          isCompleted: true,
          phase: 1,
          version: 2,
          updatedAt: "2026-03-19T10:00:00.000Z",
        },
        timestamp: "2026-03-19T10:00:00.000Z",
      },
    ],
  });

  assert.equal(parsed, null);
});
