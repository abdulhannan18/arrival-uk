"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const taskSync_1 = require("./taskSync");
function makeOperation(overrides = {}) {
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
(0, node_test_1.default)("same operationId from same client returns the cached response without reapplying", () => {
    const operation = makeOperation();
    const serverTimestamp = new Date("2026-03-19T10:05:00.000Z");
    const first = taskSync_1.__private__.processOperation(operation, serverTimestamp);
    const replay = taskSync_1.__private__.processOperation(operation, new Date("2026-03-19T10:06:00.000Z"), undefined, { statusCode: first.statusCode, result: first.result });
    strict_1.default.equal(first.statusCode, 200);
    strict_1.default.equal(replay.statusCode, 200);
    strict_1.default.deepEqual(replay.result, first.result);
});
(0, node_test_1.default)("stale versions are rejected with precondition failed and server state", () => {
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
    const outcome = taskSync_1.__private__.processOperation(operation, new Date("2026-03-19T10:05:00.000Z"), existing);
    strict_1.default.equal(outcome.statusCode, 412);
    strict_1.default.equal(outcome.result.accepted, false);
    strict_1.default.equal(outcome.result.serverVersion, 3);
    strict_1.default.deepEqual(outcome.result.conflictPayload, existing);
});
(0, node_test_1.default)("same version with different payload yields a conflict", () => {
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
    const outcome = taskSync_1.__private__.processOperation(operation, new Date("2026-03-19T10:05:00.000Z"), existing);
    strict_1.default.equal(outcome.statusCode, 409);
    strict_1.default.equal(outcome.result.accepted, false);
    strict_1.default.deepEqual(outcome.result.conflictPayload, existing);
});
//# sourceMappingURL=taskSync.test.js.map