import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { createHash } from "crypto";
import { Collections } from "./constants";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const MAX_OPERATIONS_PER_BATCH = 100;
const RETRY_AFTER_SECONDS = 60;
const MAX_STRING_LENGTH = 256;

type TaskSyncTaskDTO = {
  id: string;
  title: string;
  categoryID: string;
  isCompleted: boolean;
  phase: number;
  version: number;
  updatedAt: string;
};

type TaskSyncOperationRequest = {
  clientId: string;
  deviceId: string;
  operationId: string;
  operationType: string;
  entityId: string;
  entityVersion: number;
  payload: TaskSyncTaskDTO;
  timestamp: string;
};

type TaskSyncBatchRequest = {
  clientId: string;
  deviceId: string;
  sentAt: string;
  operations: TaskSyncOperationRequest[];
};

type TaskSyncOperationResult = {
  operationId: string;
  accepted: boolean;
  serverVersion: number;
  serverTimestamp: string;
  conflictPayload?: TaskSyncTaskDTO;
};

type CachedOperationRecord = {
  statusCode: number;
  result: TaskSyncOperationResult;
};

type ProcessOperationOutcome = {
  statusCode: number;
  result: TaskSyncOperationResult;
  nextTask?: TaskSyncTaskDTO;
};

type StoredTaskRecord = TaskSyncTaskDTO & {
  storedAt: string;
};

type StoredOperationRecord = CachedOperationRecord & {
  clientId: string;
  deviceId: string;
  operationId: string;
  createdAt: string;
};

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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function safeString(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, MAX_STRING_LENGTH);
}

function safeInteger(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.trunc(parsed);
}

function safeISODate(value: unknown): string {
  if (typeof value !== "string") return new Date(0).toISOString();
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return new Date(0).toISOString();
  return parsed.toISOString();
}

function parseTaskDTO(value: unknown): TaskSyncTaskDTO | null {
  if (!isRecord(value)) return null;

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

function parseOperationRequest(value: unknown): TaskSyncOperationRequest | null {
  if (!isRecord(value)) return null;

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

function parseBatchRequest(value: unknown): TaskSyncBatchRequest | null {
  if (!isRecord(value)) return null;

  const clientId = safeString(value.clientId);
  const deviceId = safeString(value.deviceId);
  const rawOperations = Array.isArray(value.operations) ? value.operations : [];
  const parsedOperations = rawOperations.map(parseOperationRequest);
  if (!clientId || !deviceId || rawOperations.length === 0) {
    return null;
  }

  if (parsedOperations.some((operation) => operation === null)) {
    return null;
  }

  const operations = parsedOperations as TaskSyncOperationRequest[];

  return {
    clientId,
    deviceId,
    sentAt: safeISODate(value.sentAt),
    operations,
  };
}

function buildOperationCacheKey(clientId: string, operationId: string): string {
  return createHash("sha256").update(`${clientId}:${operationId}`).digest("hex");
}

function buildEntityDocumentKey(entityId: string): string {
  return createHash("sha256").update(entityId).digest("hex");
}

function taskPayloadMatches(left: TaskSyncTaskDTO, right: TaskSyncTaskDTO): boolean {
  return left.id === right.id
    && left.title === right.title
    && left.categoryID === right.categoryID
    && left.isCompleted === right.isCompleted
    && left.phase === right.phase
    && left.version === right.version;
}

function acceptedResult(
  operation: TaskSyncOperationRequest,
  serverVersion: number,
  serverTimestamp: string
): TaskSyncOperationResult {
  return {
    operationId: operation.operationId,
    accepted: true,
    serverVersion,
    serverTimestamp,
  };
}

function rejectedResult(
  operation: TaskSyncOperationRequest,
  statusCode: number,
  serverVersion: number,
  serverTimestamp: string,
  conflictPayload?: TaskSyncTaskDTO
): CachedOperationRecord {
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

function processOperation(
  operation: TaskSyncOperationRequest,
  serverTimestamp: Date,
  existingTask?: TaskSyncTaskDTO,
  cachedOperation?: CachedOperationRecord
): ProcessOperationOutcome {
  const serverTimestampISO = serverTimestamp.toISOString();

  if (cachedOperation) {
    return cachedOperation;
  }

  if (!existingTask) {
    const nextTask: TaskSyncTaskDTO = {
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
    return rejectedResult(
      operation,
      412,
      existingTask.version,
      serverTimestampISO,
      existingTask
    );
  }

  if (operation.entityVersion === existingTask.version) {
    if (taskPayloadMatches(existingTask, operation.payload)) {
      return {
        statusCode: 200,
        result: acceptedResult(operation, existingTask.version, serverTimestampISO),
      };
    }

    return rejectedResult(
      operation,
      409,
      existingTask.version,
      serverTimestampISO,
      existingTask
    );
  }

  const nextTask: TaskSyncTaskDTO = {
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

function operationCollectionRef(): FirebaseFirestore.CollectionReference {
  return db.collection(Collections.ops.root)
    .doc(Collections.ops.taskSyncOperations)
    .collection(Collections.ops.items);
}

function taskCollectionRef(): FirebaseFirestore.CollectionReference {
  return db.collection(Collections.content.root)
    .doc(Collections.content.syncedTasks)
    .collection(Collections.content.items);
}

function parseStoredTaskRecord(data: FirebaseFirestore.DocumentData | undefined): TaskSyncTaskDTO | undefined {
  if (!data) return undefined;
  const parsed = parseTaskDTO(data);
  return parsed ?? undefined;
}

function parseStoredOperationRecord(data: FirebaseFirestore.DocumentData | undefined): CachedOperationRecord | undefined {
  if (!data || !isRecord(data.result)) return undefined;

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

async function applyOperationWithFirestore(
  operation: TaskSyncOperationRequest,
  batchClientId: string,
  batchDeviceId: string
): Promise<CachedOperationRecord> {
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
    const outcome = processOperation(
      operation,
      serverTimestamp,
      existingTask,
      cachedRecord
    );

    if (!cachedRecord) {
      const storedOperation: StoredOperationRecord = {
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
      const storedTask: StoredTaskRecord = {
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

export const taskSync = functions.https.onRequest(async (request, response) => {
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

  const results: TaskSyncOperationResult[] = [];
  let statusCode = 200;

  try {
    for (const operation of parsedRequest.operations) {
      const outcome = await applyOperationWithFirestore(
        operation,
        parsedRequest.clientId,
        parsedRequest.deviceId
      );
      results.push(outcome.result);

      if (statusCode === 200 && outcome.statusCode !== 200) {
        statusCode = outcome.statusCode;
      }
    }
  } catch (error) {
    functions.logger.error("task_sync_unavailable", {
      error: error instanceof Error ? error.message : "unknown_error",
    });
    response.status(503).json({ error: "task_sync_unavailable" });
    return;
  }

  response.status(statusCode).json({ results });
});

export const __private__ = {
  parseBatchRequest,
  buildOperationCacheKey,
  buildEntityDocumentKey,
  processOperation,
};
