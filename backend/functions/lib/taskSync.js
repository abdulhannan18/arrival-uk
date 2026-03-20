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
Object.defineProperty(exports, "__esModule", { value: true });
exports.__private__ = exports.taskSync = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const crypto_1 = require("crypto");
const constants_1 = require("./constants");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const MAX_OPERATIONS_PER_BATCH = 100;
const RETRY_AFTER_SECONDS = 60;
const MAX_STRING_LENGTH = 256;
/*
 HTTP contract: POST /v1/tasks/sync
 Request body: { clientId, deviceId, sentAt, operations[] }
 Required per operation: clientId, deviceId, operationId, operationType, entityId, entityVersion, payload, timestamp
 Success body: { results: [{ operationId, accepted, serverVersion, serverTimestamp, conflictPayload? }] }
 Error bodies:
 - 409 Conflict: same response shape with accepted=false and conflictPayload containing current server task state
 - 412 Precondition Failed: same response shape with accepted=false and conflictPayload containing current server task state
 - 429 Too Many Requests: JSON error + Retry-After header
 - 503 Service Unavailable: JSON error
 Idempotency contract: the same { clientId, operationId } pair returns the cached response without re-applying the task mutation.
 */
function isRecord(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function safeString(value) {
    if (typeof value !== "string")
        return "";
    return value.trim().slice(0, MAX_STRING_LENGTH);
}
function safeInteger(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.trunc(parsed);
}
function safeISODate(value) {
    if (typeof value !== "string")
        return new Date(0).toISOString();
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime()))
        return new Date(0).toISOString();
    return parsed.toISOString();
}
function parseTaskDTO(value) {
    if (!isRecord(value))
        return null;
    const id = safeString(value.id);
    const title = safeString(value.title);
    const categoryID = safeString(value.categoryID);
    const version = safeInteger(value.version);
    const phase = safeInteger(value.phase);
    if (!id || !title || !categoryID || version < 1) {
        return null;
    }
    return {
        id,
        title,
        categoryID,
        isCompleted: Boolean(value.isCompleted),
        phase,
        version,
        updatedAt: safeISODate(value.updatedAt),
    };
}
function parseOperationRequest(value) {
    if (!isRecord(value))
        return null;
    const clientId = safeString(value.clientId);
    const deviceId = safeString(value.deviceId);
    const operationId = safeString(value.operationId);
    const operationType = safeString(value.operationType);
    const entityId = safeString(value.entityId);
    const entityVersion = safeInteger(value.entityVersion);
    const payload = parseTaskDTO(value.payload);
    if (!clientId || !deviceId || !operationId || !operationType || !entityId || entityVersion < 1 || !payload) {
        return null;
    }
    return {
        clientId,
        deviceId,
        operationId,
        operationType,
        entityId,
        entityVersion,
        payload,
        timestamp: safeISODate(value.timestamp),
    };
}
function parseBatchRequest(value) {
    if (!isRecord(value))
        return null;
    const clientId = safeString(value.clientId);
    const deviceId = safeString(value.deviceId);
    const operations = Array.isArray(value.operations)
        ? value.operations
            .map(parseOperationRequest)
            .filter((operation) => operation !== null)
        : [];
    if (!clientId || !deviceId || operations.length === 0) {
        return null;
    }
    return {
        clientId,
        deviceId,
        sentAt: safeISODate(value.sentAt),
        operations,
    };
}
function buildOperationCacheKey(clientId, operationId) {
    return (0, crypto_1.createHash)("sha256").update(`${clientId}:${operationId}`).digest("hex");
}
function buildEntityDocumentKey(entityId) {
    return (0, crypto_1.createHash)("sha256").update(entityId).digest("hex");
}
function taskPayloadMatches(left, right) {
    return left.id === right.id
        && left.title === right.title
        && left.categoryID === right.categoryID
        && left.isCompleted === right.isCompleted
        && left.phase === right.phase
        && left.version === right.version;
}
function acceptedResult(operation, serverVersion, serverTimestamp) {
    return {
        operationId: operation.operationId,
        accepted: true,
        serverVersion,
        serverTimestamp,
    };
}
function rejectedResult(operation, statusCode, serverVersion, serverTimestamp, conflictPayload) {
    return {
        statusCode,
        result: {
            operationId: operation.operationId,
            accepted: false,
            serverVersion,
            serverTimestamp,
            conflictPayload: conflictPayload ?? undefined,
        },
    };
}
function processOperation(operation, serverTimestamp, existingTask, cachedOperation) {
    const serverTimestampISO = serverTimestamp.toISOString();
    if (cachedOperation) {
        return cachedOperation;
    }
    if (!existingTask) {
        const nextTask = {
            ...operation.payload,
            version: operation.entityVersion,
            updatedAt: serverTimestampISO,
        };
        return {
            statusCode: 200,
            result: acceptedResult(operation, nextTask.version, serverTimestampISO),
            nextTask,
        };
    }
    if (operation.entityVersion < existingTask.version || operation.entityVersion > existingTask.version + 1) {
        return rejectedResult(operation, 412, existingTask.version, serverTimestampISO, existingTask);
    }
    if (operation.entityVersion === existingTask.version) {
        if (taskPayloadMatches(existingTask, operation.payload)) {
            return {
                statusCode: 200,
                result: acceptedResult(operation, existingTask.version, serverTimestampISO),
            };
        }
        return rejectedResult(operation, 409, existingTask.version, serverTimestampISO, existingTask);
    }
    const nextTask = {
        ...operation.payload,
        version: operation.entityVersion,
        updatedAt: serverTimestampISO,
    };
    return {
        statusCode: 200,
        result: acceptedResult(operation, nextTask.version, serverTimestampISO),
        nextTask,
    };
}
function operationCollectionRef() {
    return db.collection(constants_1.Collections.ops.root)
        .doc(constants_1.Collections.ops.taskSyncOperations)
        .collection(constants_1.Collections.ops.items);
}
function taskCollectionRef() {
    return db.collection(constants_1.Collections.content.root)
        .doc(constants_1.Collections.content.syncedTasks)
        .collection(constants_1.Collections.content.items);
}
function parseStoredTaskRecord(data) {
    if (!data)
        return undefined;
    const parsed = parseTaskDTO(data);
    return parsed ?? undefined;
}
function parseStoredOperationRecord(data) {
    if (!data || !isRecord(data.result))
        return undefined;
    const result = data.result;
    const operationId = safeString(result.operationId);
    const accepted = Boolean(result.accepted);
    const serverVersion = safeInteger(result.serverVersion);
    const serverTimestamp = safeISODate(result.serverTimestamp);
    const conflictPayload = parseTaskDTO(result.conflictPayload);
    const statusCode = safeInteger(data.statusCode);
    if (!operationId || serverVersion < 0 || statusCode < 200) {
        return undefined;
    }
    return {
        statusCode,
        result: {
            operationId,
            accepted,
            serverVersion,
            serverTimestamp,
            conflictPayload: conflictPayload ?? undefined,
        },
    };
}
async function applyOperationWithFirestore(operation, batchClientId, batchDeviceId) {
    const operationKey = buildOperationCacheKey(batchClientId, operation.operationId);
    const entityKey = buildEntityDocumentKey(operation.entityId);
    const operationRef = operationCollectionRef().doc(operationKey);
    const taskRef = taskCollectionRef().doc(entityKey);
    return db.runTransaction(async (transaction) => {
        const [cachedSnapshot, taskSnapshot] = await Promise.all([
            transaction.get(operationRef),
            transaction.get(taskRef),
        ]);
        const cachedRecord = parseStoredOperationRecord(cachedSnapshot.data());
        const existingTask = parseStoredTaskRecord(taskSnapshot.data());
        const serverTimestamp = new Date();
        const outcome = processOperation(operation, serverTimestamp, existingTask, cachedRecord);
        if (!cachedRecord) {
            const storedOperation = {
                statusCode: outcome.statusCode,
                result: outcome.result,
                clientId: batchClientId,
                deviceId: batchDeviceId,
                operationId: operation.operationId,
                createdAt: serverTimestamp.toISOString(),
            };
            transaction.set(operationRef, storedOperation);
        }
        if (!cachedRecord && outcome.nextTask) {
            const storedTask = {
                ...outcome.nextTask,
                storedAt: serverTimestamp.toISOString(),
            };
            transaction.set(taskRef, storedTask);
        }
        return {
            statusCode: outcome.statusCode,
            result: outcome.result,
        };
    });
}
exports.taskSync = functions.https.onRequest(async (request, response) => {
    if (request.method !== "POST") {
        response.set("Allow", "POST");
        response.status(405).json({ error: "method_not_allowed" });
        return;
    }
    const parsedRequest = parseBatchRequest(request.body);
    if (!parsedRequest) {
        response.status(400).json({ error: "invalid_task_sync_request" });
        return;
    }
    if (parsedRequest.operations.length > MAX_OPERATIONS_PER_BATCH) {
        response.set("Retry-After", String(RETRY_AFTER_SECONDS));
        response.status(429).json({ error: "task_sync_rate_limited" });
        return;
    }
    const results = [];
    let statusCode = 200;
    try {
        for (const operation of parsedRequest.operations) {
            const outcome = await applyOperationWithFirestore(operation, parsedRequest.clientId, parsedRequest.deviceId);
            results.push(outcome.result);
            if (outcome.statusCode !== 200) {
                statusCode = outcome.statusCode;
                break;
            }
        }
    }
    catch (error) {
        functions.logger.error("task_sync_unavailable", {
            error: error instanceof Error ? error.message : "unknown_error",
        });
        response.status(503).json({ error: "task_sync_unavailable" });
        return;
    }
    response.status(statusCode).json({ results });
});
exports.__private__ = {
    parseBatchRequest,
    buildOperationCacheKey,
    buildEntityDocumentKey,
    processOperation,
};
//# sourceMappingURL=taskSync.js.map