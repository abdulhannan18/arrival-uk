import Foundation
import Network
import Observation
import SwiftData
import SwiftUI

enum TaskSyncStatus: String, Codable {
    case synced
    case pending
}

enum TaskSyncOperationType: String, Codable {
    case upsertTask = "upsert_task"
}

enum TaskSyncFailure: Error, Equatable, CustomStringConvertible {
    case transport(String)
    case httpStatus(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case serviceUnavailable
    case conflict
    case preconditionFailed
    case decoding(String)
    case queueOverflow
    case cancelled
    case storage(String)
    case validation(String)

    var description: String {
        switch self {
        case .transport(let message):
            return message
        case .httpStatus(let status):
            return "http_\(status)"
        case .rateLimited:
            return "rate_limited"
        case .serviceUnavailable:
            return "service_unavailable"
        case .conflict:
            return "conflict"
        case .preconditionFailed:
            return "precondition_failed"
        case .decoding(let message):
            return message
        case .queueOverflow:
            return "queue_overflow"
        case .cancelled:
            return "cancelled"
        case .storage(let message):
            return message
        case .validation(let message):
            return message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .transport, .rateLimited, .serviceUnavailable:
            return true
        case .httpStatus(let status):
            return status == 429 || status == 503
        case .conflict,
             .preconditionFailed,
             .decoding,
             .queueOverflow,
             .cancelled,
             .storage,
             .validation:
            return false
        }
    }
}

struct TaskSyncResolvedTaskVersion: Codable, Hashable {
    let id: String
    let title: String
    let categoryID: String
    let isCompleted: Bool
    let phase: Int
    let version: Int
    let updatedAt: Date
}

struct TaskSyncConflictResolutionEvent: Identifiable, Hashable {
    let id: String
    let operationID: String
    let localVersion: TaskSyncResolvedTaskVersion
    let remoteVersion: TaskSyncResolvedTaskVersion
    let generatedAt: Date
}

enum TaskSyncConflictResolutionStrategy {
    case serverWins
    case clientWins
    /// Deprecated for distributed correctness. This now aliases to server-authoritative resolution.
    case lastWriteWinsByUpdatedAt
    case manualResolution
}

enum TaskSyncLifecycleState: Equatable {
    case idle
    case syncing
    case pendingRetry(retryCount: Int, lastError: TaskSyncFailure)
    case conflicted(localVersion: TaskSyncResolvedTaskVersion, remoteVersion: TaskSyncResolvedTaskVersion)
    case failed(TaskSyncFailure)
}

@Model
final class TaskEntity {
    @Attribute(.unique) var id: String
    var title: String
    var categoryID: String
    var isCompleted: Bool
    var phase: Int
    var lastModified: Date
    var version: Int
    var lastServerVersion: Int
    var lastOperationID: String?
    var syncStatusRaw: String

    init(
        id: String,
        title: String,
        categoryID: String,
        isCompleted: Bool,
        phase: Int,
        lastModified: Date,
        version: Int,
        lastServerVersion: Int,
        lastOperationID: String?,
        syncStatus: TaskSyncStatus
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.isCompleted = isCompleted
        self.phase = phase
        self.lastModified = lastModified
        self.version = version
        self.lastServerVersion = lastServerVersion
        self.lastOperationID = lastOperationID
        self.syncStatusRaw = syncStatus.rawValue
    }

    var syncStatus: TaskSyncStatus {
        get { TaskSyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    var resolvedVersion: TaskSyncResolvedTaskVersion {
        TaskSyncResolvedTaskVersion(
            id: id,
            title: title,
            categoryID: categoryID,
            isCompleted: isCompleted,
            phase: phase,
            version: version,
            updatedAt: lastModified
        )
    }
}

@Model
final class TaskSyncOperationEntity {
    @Attribute(.unique) var operationID: String
    var clientID: String
    var deviceID: String
    var operationTypeRaw: String
    var entityID: String
    var entityVersion: Int
    var title: String
    var categoryID: String
    var isCompleted: Bool
    var phase: Int
    var createdAt: Date
    var lastModified: Date
    var retryCount: Int
    var lastErrorMessage: String?
    var lastAttemptAt: Date?
    var ordinal: Int64

    init(
        operationID: String,
        clientID: String,
        deviceID: String,
        operationType: TaskSyncOperationType,
        entityID: String,
        entityVersion: Int,
        title: String,
        categoryID: String,
        isCompleted: Bool,
        phase: Int,
        createdAt: Date,
        lastModified: Date,
        retryCount: Int,
        lastErrorMessage: String?,
        lastAttemptAt: Date?,
        ordinal: Int64
    ) {
        self.operationID = operationID
        self.clientID = clientID
        self.deviceID = deviceID
        self.operationTypeRaw = operationType.rawValue
        self.entityID = entityID
        self.entityVersion = entityVersion
        self.title = title
        self.categoryID = categoryID
        self.isCompleted = isCompleted
        self.phase = phase
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.retryCount = retryCount
        self.lastErrorMessage = lastErrorMessage
        self.lastAttemptAt = lastAttemptAt
        self.ordinal = ordinal
    }

    var operationType: TaskSyncOperationType {
        get { TaskSyncOperationType(rawValue: operationTypeRaw) ?? .upsertTask }
        set { operationTypeRaw = newValue.rawValue }
    }

    var resolvedVersion: TaskSyncResolvedTaskVersion {
        TaskSyncResolvedTaskVersion(
            id: entityID,
            title: title,
            categoryID: categoryID,
            isCompleted: isCompleted,
            phase: phase,
            version: entityVersion,
            updatedAt: lastModified
        )
    }
}

struct TaskSyncRequestTimeouts: Equatable {
    let connectTimeout: TimeInterval
    let requestTimeout: TimeInterval
}

protocol TaskSyncTransport {
    func send(
        request: TaskSyncBatchRequest,
        timeout: TaskSyncRequestTimeouts
    ) async throws -> TaskSyncBatchResponse
}

enum TaskSyncTransportError: Error {
    case conflict(TaskSyncBatchResponse?)
    case preconditionFailed(TaskSyncBatchResponse?)
    case rateLimited(retryAfter: TimeInterval?)
    case serviceUnavailable
    case httpStatus(Int)
    case transport(Error)
    case decoding(Error)
    case cancelled
}

@available(iOS 17.0, *)
private struct TaskSyncHTTPTransport: TaskSyncTransport {
    private let endpoint: String

    init(
        endpoint: String = AppConfig.apiBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("tasks")
            .appendingPathComponent("sync")
            .absoluteString
    ) {
        self.endpoint = endpoint
    }

    func send(
        request: TaskSyncBatchRequest,
        timeout: TaskSyncRequestTimeouts
    ) async throws -> TaskSyncBatchResponse {
        let configuration = makeTaskSyncSessionConfiguration(for: timeout)
        let client = SecureHTTPClient(configuration: configuration, honorsConfigurationTimeouts: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let body = try encoder.encode(request)
        do {
            let rawResponse = try await client.execute(
                endpoint: endpoint,
                method: .post,
                headers: ["Accept": "application/json"],
                body: body
            )

            let statusCode = rawResponse.response.statusCode
            guard (200 ... 299).contains(statusCode) else {
                let decodedBody = try? decoder.decode(TaskSyncBatchResponse.self, from: rawResponse.data)
                switch statusCode {
                case 409:
                    throw TaskSyncTransportError.conflict(decodedBody)
                case 412:
                    throw TaskSyncTransportError.preconditionFailed(decodedBody)
                case 429:
                    throw TaskSyncTransportError.rateLimited(
                        retryAfter: Self.retryAfter(from: rawResponse.response)
                    )
                case 503:
                    throw TaskSyncTransportError.serviceUnavailable
                default:
                    throw TaskSyncTransportError.httpStatus(statusCode)
                }
            }

            return try decoder.decode(TaskSyncBatchResponse.self, from: rawResponse.data)
        } catch is CancellationError {
            throw TaskSyncTransportError.cancelled
        } catch let error as TaskSyncTransportError {
            throw error
        } catch let error as SecureHTTPClientError {
            throw TaskSyncTransportError.transport(error)
        } catch {
            throw TaskSyncTransportError.decoding(error)
        }
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let rawValue = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return seconds
        }
        return nil
    }
}

struct TaskSyncBatchRequest: Codable, Equatable {
    let clientId: String
    let deviceId: String
    let sentAt: Date
    let operations: [TaskSyncOperationRequest]
}

struct TaskSyncOperationRequest: Codable, Equatable {
    let clientId: String
    let deviceId: String
    let operationId: String
    let operationType: String
    let entityId: String
    let entityVersion: Int
    let payload: TaskSyncTaskDTO
    let timestamp: Date
}

struct TaskSyncBatchResponse: Codable, Equatable {
    let results: [TaskSyncOperationResult]

    init(results: [TaskSyncOperationResult]) {
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([TaskSyncOperationResult].self, forKey: .results) ?? []
    }
}

struct TaskSyncOperationResult: Codable, Equatable {
    let operationId: String
    let accepted: Bool
    let serverVersion: Int
    let serverTimestamp: Date
    let conflictPayload: TaskSyncTaskDTO?
}

struct TaskSyncTaskDTO: Codable, Equatable {
    let id: String
    let title: String
    let categoryID: String
    let isCompleted: Bool
    let phase: Int
    let version: Int
    let updatedAt: Date
}

struct TaskSyncOperationSnapshot: Equatable {
    let operationID: String
    let entityID: String
    let entityVersion: Int
    let retryCount: Int
    let ordinal: Int64
}

/*
 Sync remediation notes:
 1. Intended mechanism: optimistic local-first task sync with a durable ordered operation log,
    explicit server acknowledgements, and last-write-wins conflict handling by task `updatedAt`.
 2. Broken behavior before this change: local mutations were marked synced before the server
    acknowledged them, partial responses silently dropped user state, and pending work lived only
    as coarse task flags instead of a replayable operation queue.
 3. Missing backend contract before this change: the client assumed `/v1/tasks/sync` existed and
    echoed per-operation acceptance + version metadata. The matching stub contract now lives in the
    backend task sync function so the client is no longer targeting a phantom route.
 */
@available(iOS 17.0, *)
@MainActor
@Observable
final class TaskSyncStore {
    static let shared = TaskSyncStore()

    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private let pathMonitorQueue = DispatchQueue(label: "com.arrivaluk.tasksync.path-monitor")
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let transport: any TaskSyncTransport
    @ObservationIgnored private let nowProvider: @Sendable () -> Date
    @ObservationIgnored private let sleepProvider: @Sendable (TimeInterval) async -> Void
    @ObservationIgnored private let jitterProvider: @Sendable () -> Double
    @ObservationIgnored private let queueLimit: Int
    @ObservationIgnored private let retryBaseDelaySeconds: TimeInterval = 1
    @ObservationIgnored private let retryDelayCapSeconds: TimeInterval = 30
    @ObservationIgnored private let maximumRetryAttempts = 5
    @ObservationIgnored private let minimumSyncInterval: TimeInterval = 1
    @ObservationIgnored private let requestTimeouts = TaskSyncRequestTimeouts(
        connectTimeout: 10,
        requestTimeout: 30
    )
    @ObservationIgnored private let container: ModelContainer?

    @ObservationIgnored private var lastSyncAttemptAt: Date?
    @ObservationIgnored private var hasConfigured = false
    @ObservationIgnored private var isNetworkReachable = true
    @ObservationIgnored private var activeDrainTask: Task<Void, Never>?
    @ObservationIgnored private let clientID: String
    @ObservationIgnored private let deviceID: String

    var pendingUpdateCount = 0
    var syncState: TaskSyncLifecycleState = .idle
    var lastConflictEvent: TaskSyncConflictResolutionEvent?
    var conflictResolutionStrategy: TaskSyncConflictResolutionStrategy = .serverWins

    init(
        defaults: UserDefaults = .standard,
        container: ModelContainer? = nil,
        configuration: ModelConfiguration? = nil,
        transport: (any TaskSyncTransport)? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        sleepProvider: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        jitterProvider: @escaping @Sendable () -> Double = {
            Double.random(in: 0.5 ... 1.0)
        },
        queueLimit: Int = 500
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        self.sleepProvider = sleepProvider
        self.jitterProvider = jitterProvider
        self.queueLimit = queueLimit
        self.clientID = TaskSyncStore.resolveIdentifier(
            for: .taskSyncClientID,
            prefix: "client",
            defaults: defaults
        )
        self.deviceID = TaskSyncStore.resolveIdentifier(
            for: .taskSyncDeviceID,
            prefix: "device",
            defaults: defaults
        )

        if let container {
            self.container = container
        } else {
            do {
                if let configuration {
                    self.container = try ModelContainer(
                        for: TaskEntity.self,
                        TaskSyncOperationEntity.self,
                        configurations: configuration
                    )
                } else {
                    self.container = try ModelContainer(
                        for: TaskEntity.self,
                        TaskSyncOperationEntity.self
                    )
                }
            } catch {
                self.container = nil
                CrashReporter.record(error: error, context: "task_sync_container_init")
            }
        }

        self.transport = transport ?? TaskSyncHTTPTransport()
        pendingUpdateCount = localPendingCount()
    }

    deinit {
        pathMonitor.cancel()
        activeDrainTask?.cancel()
    }

    func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isNetworkReachable = path.status == .satisfied
                if self.isNetworkReachable {
                    await self.flushPendingUpdatesIfNeeded(reason: "network_restored", force: true)
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)

        Task { @MainActor in
            await flushPendingUpdatesIfNeeded(reason: "startup", force: true)
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task { @MainActor in
                await flushPendingUpdatesIfNeeded(reason: "scene_active", force: true)
            }
        } else {
            cancelInFlightSync(reason: "scene_\(phase)")
        }
    }

    func cancelInFlightSync(reason: String) {
        activeDrainTask?.cancel()
        activeDrainTask = nil
        if syncState == .syncing {
            syncState = .failed(.cancelled)
        }
        CrashReporter.log("task_sync_cancelled reason=\(reason)", level: .info)
    }

    func mirrorQueues(survivalQueue: [AppTask], maintenanceTasks: [AppTask]) {
        guard let context = makeContext() else {
            syncState = .failed(.storage("missing_task_sync_container"))
            return
        }

        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            var entitiesByID = Dictionary(uniqueKeysWithValues: allEntities.map { ($0.id, $0) })
            let now = nowProvider()

            for task in survivalQueue {
                try upsertQueuedTask(
                    task: task,
                    phase: 1,
                    now: now,
                    context: context,
                    entitiesByID: &entitiesByID
                )
            }

            for task in maintenanceTasks {
                try upsertQueuedTask(
                    task: task,
                    phase: 2,
                    now: now,
                    context: context,
                    entitiesByID: &entitiesByID
                )
            }

            try context.save()
            pendingUpdateCount = localPendingCount(existingContext: context)
        } catch let failure as TaskSyncFailure {
            syncState = .failed(failure)
        } catch {
            syncState = .failed(.storage("task_sync_mirror_queues"))
            CrashReporter.record(error: error, context: "task_sync_mirror_queues")
        }
    }

    func recordCompletion(
        taskID: String,
        title: String,
        categoryID: String,
        phase: Int,
        completedAt: Date = .now
    ) {
        do {
            try persistLocalMutation(
                taskID: taskID,
                title: title,
                categoryID: categoryID,
                phase: phase,
                isCompleted: true,
                changedAt: completedAt
            )
            Task { @MainActor in
                await flushPendingUpdatesIfNeeded(reason: "task_completed", force: false)
            }
        } catch let failure as TaskSyncFailure {
            syncState = .failed(failure)
        } catch {
            syncState = .failed(.storage("task_sync_record_completion"))
            CrashReporter.record(error: error, context: "task_sync_record_completion")
        }
    }

    func localCompletionMap() -> [String: Date] {
        guard let context = makeContext() else { return [:] }

        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            var map: [String: Date] = [:]
            for entity in allEntities where entity.isCompleted {
                let existing = map[entity.id] ?? .distantPast
                if entity.lastModified > existing {
                    map[entity.id] = entity.lastModified
                }
            }
            return map
        } catch {
            CrashReporter.record(error: error, context: "task_sync_local_completion_map")
            return [:]
        }
    }

    func flushPendingUpdatesIfNeeded(reason: String, force: Bool) async {
        guard isNetworkReachable else { return }
        guard activeDrainTask == nil else { return }
        guard pendingUpdateCount > 0 else {
            pendingUpdateCount = localPendingCount()
            if pendingUpdateCount == 0 {
                syncState = .idle
            }
            return
        }

        let now = nowProvider()
        if !force,
           let lastSyncAttemptAt,
           now.timeIntervalSince(lastSyncAttemptAt) < minimumSyncInterval {
            return
        }

        lastSyncAttemptAt = now
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.drainPendingOperations(reason: reason)
        }
        activeDrainTask = task
        await task.value
        if activeDrainTask?.isCancelled == false {
            activeDrainTask = nil
        }
    }

    func pendingOperationsForTesting() -> [TaskSyncOperationSnapshot] {
        guard let context = makeContext() else { return [] }
        do {
            return try fetchPendingOperations(context: context).map {
                TaskSyncOperationSnapshot(
                    operationID: $0.operationID,
                    entityID: $0.entityID,
                    entityVersion: $0.entityVersion,
                    retryCount: $0.retryCount,
                    ordinal: $0.ordinal
                )
            }
        } catch {
            return []
        }
    }

    func taskVersionsForTesting() -> [TaskSyncResolvedTaskVersion] {
        guard let context = makeContext() else { return [] }
        do {
            return try context.fetch(FetchDescriptor<TaskEntity>())
                .map(\.resolvedVersion)
                .sorted { $0.id < $1.id }
        } catch {
            return []
        }
    }

    nonisolated static func retryDelaySeconds(forAttempt attempt: Int, jitter: Double) -> TimeInterval {
        let normalizedAttempt = max(1, attempt)
        let cappedBase = min(pow(2.0, Double(normalizedAttempt - 1)), 30.0)
        let boundedJitter = min(max(jitter, 0.5), 1.0)
        return min(cappedBase * boundedJitter, 30.0)
    }

    private func drainPendingOperations(reason: String) async {
        guard let context = makeContext() else {
            syncState = .failed(.storage("missing_task_sync_container"))
            return
        }

        do {
            while !Task.isCancelled {
                guard let operation = try fetchNextPendingOperation(context: context) else {
                    pendingUpdateCount = 0
                    syncState = .idle
                    return
                }

                syncState = .syncing
                operation.lastAttemptAt = nowProvider()

                do {
                    let request = buildBatchRequest(for: operation)
                    let response = try await transport.send(
                        request: request,
                        timeout: requestTimeouts
                    )
                    try applyResponse(
                        response,
                        for: operation,
                        context: context
                    )
                    try context.save()
                    pendingUpdateCount = try pendingOperationCount(context: context)
                    syncState = pendingUpdateCount == 0 ? .idle : .syncing
                } catch {
                    let failure = mapFailure(error)
                    operation.lastErrorMessage = failure.description
                    try context.save()

                    if failure.isRetryable, operation.retryCount < maximumRetryAttempts {
                        operation.retryCount += 1
                        syncState = .pendingRetry(
                            retryCount: operation.retryCount,
                            lastError: failure
                        )
                        try context.save()
                        let delay = Self.retryDelaySeconds(
                            forAttempt: operation.retryCount,
                            jitter: jitterProvider()
                        )
                        await sleepProvider(delay)
                        continue
                    }

                    let shouldContinue = try handleNonRetryableFailure(
                        failure,
                        underlyingError: error,
                        operation: operation,
                        context: context
                    )
                    pendingUpdateCount = try pendingOperationCount(context: context)
                    if shouldContinue {
                        continue
                    }

                    if syncState == .syncing {
                        syncState = .failed(failure)
                    }
                    CrashReporter.log(
                        "task_sync_stop reason=\(reason) failure=\(failure.description)",
                        level: .warning
                    )
                    return
                }
            }

            if Task.isCancelled {
                syncState = .failed(.cancelled)
            }
        } catch {
            syncState = .failed(.storage("task_sync_drain"))
            CrashReporter.record(error: error, context: "task_sync_drain")
        }
    }

    private func handleNonRetryableFailure(
        _ failure: TaskSyncFailure,
        underlyingError: Error,
        operation: TaskSyncOperationEntity,
        context: ModelContext
    ) throws -> Bool {
        switch underlyingError {
        case let transportError as TaskSyncTransportError:
            switch transportError {
            case .conflict(let response):
                return try resolveConflict(
                    response: response,
                    operation: operation,
                    context: context
                )
            case .preconditionFailed(let response):
                return try resolveConflict(
                    response: response,
                    operation: operation,
                    context: context
                )
            case .cancelled:
                syncState = .failed(.cancelled)
                return false
            case .rateLimited, .serviceUnavailable, .httpStatus, .transport, .decoding:
                syncState = .failed(failure)
                return false
            }
        default:
            syncState = .failed(failure)
            return false
        }
    }

    private func resolveConflict(
        response: TaskSyncBatchResponse?,
        operation: TaskSyncOperationEntity,
        context: ModelContext
    ) throws -> Bool {
        guard let result = response?.results.first(where: { $0.operationId == operation.operationID }),
              let conflictPayload = result.conflictPayload else {
            syncState = .failed(.validation("missing_conflict_payload"))
            return false
        }

        let localVersion = operation.resolvedVersion
        let remoteVersion = TaskSyncResolvedTaskVersion(dto: conflictPayload)
        let event = TaskSyncConflictResolutionEvent(
            id: UUID().uuidString,
            operationID: operation.operationID,
            localVersion: localVersion,
            remoteVersion: remoteVersion,
            generatedAt: nowProvider()
        )
        lastConflictEvent = event
        CrashReporter.log(
            "task_sync_conflict operation=\(operation.operationID) local=\(localVersion.version) remote=\(remoteVersion.version)",
            level: .warning
        )

        switch conflictResolutionStrategy {
        case .manualResolution:
            syncState = .conflicted(localVersion: localVersion, remoteVersion: remoteVersion)
            return false
        case .serverWins:
            try applyServerVersion(remoteVersion, for: operation, context: context)
            syncState = .idle
            return true
        case .clientWins:
            try requeueClientVersion(after: remoteVersion, operation: operation, context: context)
            syncState = .syncing
            return true
        case .lastWriteWinsByUpdatedAt:
            try applyServerVersion(remoteVersion, for: operation, context: context)
            syncState = .idle
            return true
        }
    }

    private func applyResponse(
        _ response: TaskSyncBatchResponse,
        for operation: TaskSyncOperationEntity,
        context: ModelContext
    ) throws {
        guard let result = response.results.first(where: { $0.operationId == operation.operationID }) else {
            throw TaskSyncFailure.validation("missing_operation_ack")
        }

        guard result.accepted else {
            throw TaskSyncTransportError.conflict(response)
        }

        let entity = try fetchTaskEntity(
            taskID: operation.entityID,
            context: context
        )

        entity.title = operation.title
        entity.categoryID = operation.categoryID
        entity.isCompleted = operation.isCompleted
        entity.phase = operation.phase
        entity.version = max(entity.version, result.serverVersion)
        entity.lastServerVersion = max(entity.lastServerVersion, result.serverVersion)
        entity.lastModified = max(entity.lastModified, result.serverTimestamp)
        entity.syncStatus = .synced
        entity.lastOperationID = operation.operationID

        context.delete(operation)
    }

    private func applyServerVersion(
        _ remoteVersion: TaskSyncResolvedTaskVersion,
        for operation: TaskSyncOperationEntity,
        context: ModelContext
    ) throws {
        let entity = try fetchTaskEntity(taskID: operation.entityID, context: context)
        entity.title = remoteVersion.title
        entity.categoryID = remoteVersion.categoryID
        entity.isCompleted = remoteVersion.isCompleted
        entity.phase = remoteVersion.phase
        entity.version = remoteVersion.version
        entity.lastServerVersion = remoteVersion.version
        entity.lastModified = remoteVersion.updatedAt
        entity.syncStatus = .synced
        entity.lastOperationID = operation.operationID
        context.delete(operation)
        try context.save()
        pendingUpdateCount = localPendingCount(existingContext: context)
    }

    private func requeueClientVersion(
        after remoteVersion: TaskSyncResolvedTaskVersion,
        operation: TaskSyncOperationEntity,
        context: ModelContext
    ) throws {
        let entity = try fetchTaskEntity(taskID: operation.entityID, context: context)
        let nextVersion = max(remoteVersion.version + 1, entity.version + 1)
        entity.version = nextVersion
        entity.lastServerVersion = max(entity.lastServerVersion, remoteVersion.version)
        entity.syncStatus = .pending
        entity.lastOperationID = operation.operationID

        operation.entityVersion = nextVersion
        operation.retryCount = 0
        operation.lastErrorMessage = nil
        try context.save()
        pendingUpdateCount = localPendingCount(existingContext: context)
    }

    private func buildBatchRequest(for operation: TaskSyncOperationEntity) -> TaskSyncBatchRequest {
        TaskSyncBatchRequest(
            clientId: operation.clientID,
            deviceId: operation.deviceID,
            sentAt: nowProvider(),
            operations: [
                TaskSyncOperationRequest(
                    clientId: operation.clientID,
                    deviceId: operation.deviceID,
                    operationId: operation.operationID,
                    operationType: operation.operationType.rawValue,
                    entityId: operation.entityID,
                    entityVersion: operation.entityVersion,
                    payload: TaskSyncTaskDTO(operation: operation),
                    timestamp: operation.createdAt
                )
            ]
        )
    }

    private func persistLocalMutation(
        taskID: String,
        title: String,
        categoryID: String,
        phase: Int,
        isCompleted: Bool,
        changedAt: Date,
        context existingContext: ModelContext? = nil
    ) throws {
        let context: ModelContext
        if let existingContext {
            context = existingContext
        } else if let createdContext = makeContext() {
            context = createdContext
        } else {
            throw TaskSyncFailure.storage("missing_task_sync_container")
        }

        let pendingCount = try pendingOperationCount(context: context)
        guard pendingCount < queueLimit else {
            throw TaskSyncFailure.queueOverflow
        }

        let trimmedTaskID = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTaskID.isEmpty else {
            throw TaskSyncFailure.validation("missing_task_id")
        }

        let entity = try fetchOrCreateTaskEntity(
            taskID: trimmedTaskID,
            title: title,
            categoryID: categoryID,
            phase: phase,
            isCompleted: isCompleted,
            changedAt: changedAt,
            context: context
        )

        entity.title = title
        entity.categoryID = categoryID
        entity.isCompleted = isCompleted
        entity.phase = phase
        entity.lastModified = changedAt
        entity.version = max(entity.version + 1, entity.lastServerVersion + 1)
        entity.syncStatus = .pending

        let operation = TaskSyncOperationEntity(
            operationID: UUID().uuidString,
            clientID: clientID,
            deviceID: deviceID,
            operationType: .upsertTask,
            entityID: trimmedTaskID,
            entityVersion: entity.version,
            title: title,
            categoryID: categoryID,
            isCompleted: isCompleted,
            phase: phase,
            createdAt: changedAt,
            lastModified: changedAt,
            retryCount: 0,
            lastErrorMessage: nil,
            lastAttemptAt: nil,
            ordinal: nextOperationOrdinal()
        )
        entity.lastOperationID = operation.operationID
        context.insert(operation)
        try context.save()
        pendingUpdateCount = localPendingCount(existingContext: context)
    }

    private func fetchOrCreateTaskEntity(
        taskID: String,
        title: String,
        categoryID: String,
        phase: Int,
        isCompleted: Bool,
        changedAt: Date,
        context: ModelContext
    ) throws -> TaskEntity {
        let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
        if let existing = allEntities.first(where: { $0.id == taskID }) {
            return existing
        }

        let entity = TaskEntity(
            id: taskID,
            title: title,
            categoryID: categoryID,
            isCompleted: isCompleted,
            phase: phase,
            lastModified: changedAt,
            version: 0,
            lastServerVersion: 0,
            lastOperationID: nil,
            syncStatus: .synced
        )
        context.insert(entity)
        return entity
    }

    private func fetchTaskEntity(taskID: String, context: ModelContext) throws -> TaskEntity {
        let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
        if let entity = allEntities.first(where: { $0.id == taskID }) {
            return entity
        }

        let entity = TaskEntity(
            id: taskID,
            title: "",
            categoryID: "",
            isCompleted: false,
            phase: 2,
            lastModified: nowProvider(),
            version: 0,
            lastServerVersion: 0,
            lastOperationID: nil,
            syncStatus: .synced
        )
        context.insert(entity)
        return entity
    }

    private func upsertQueuedTask(
        task: AppTask,
        phase: Int,
        now: Date,
        context: ModelContext,
        entitiesByID: inout [String: TaskEntity]
    ) throws {
        if let existing = entitiesByID[task.id] {
            existing.title = task.title
            existing.categoryID = task.categoryID
            existing.phase = phase

            if existing.isCompleted {
                try persistLocalMutation(
                    taskID: task.id,
                    title: task.title,
                    categoryID: task.categoryID,
                    phase: phase,
                    isCompleted: false,
                    changedAt: now,
                    context: context
                )
            }
            return
        }

        let entity = TaskEntity(
            id: task.id,
            title: task.title,
            categoryID: task.categoryID,
            isCompleted: false,
            phase: phase,
            lastModified: now,
            version: 0,
            lastServerVersion: 0,
            lastOperationID: nil,
            syncStatus: .synced
        )
        context.insert(entity)
        entitiesByID[task.id] = entity
    }

    private func fetchPendingOperations(context: ModelContext) throws -> [TaskSyncOperationEntity] {
        try context.fetch(
            FetchDescriptor<TaskSyncOperationEntity>(
                sortBy: [SortDescriptor(\TaskSyncOperationEntity.ordinal)]
            )
        )
    }

    private func fetchNextPendingOperation(context: ModelContext) throws -> TaskSyncOperationEntity? {
        var descriptor = FetchDescriptor<TaskSyncOperationEntity>(
            sortBy: [SortDescriptor(\TaskSyncOperationEntity.ordinal)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func pendingOperationCount(context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TaskSyncOperationEntity>())
    }

    private func localPendingCount(existingContext: ModelContext? = nil) -> Int {
        guard let context = existingContext ?? makeContext() else { return 0 }
        do {
            return try pendingOperationCount(context: context)
        } catch {
            CrashReporter.record(error: error, context: "task_sync_pending_count")
            return 0
        }
    }

    private func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    private func nextOperationOrdinal() -> Int64 {
        let currentValue = defaults.object(
            forKey: StorageKey.taskSyncOperationOrdinal.rawValue
        ) as? Int64 ?? 0
        let nextValue = currentValue + 1
        defaults.set(nextValue, forKey: StorageKey.taskSyncOperationOrdinal.rawValue)
        return nextValue
    }

    private func mapFailure(_ error: Error) -> TaskSyncFailure {
        switch error {
        case let failure as TaskSyncFailure:
            return failure
        case let transportError as TaskSyncTransportError:
            switch transportError {
            case .conflict:
                return .conflict
            case .preconditionFailed:
                return .preconditionFailed
            case .rateLimited(let retryAfter):
                return .rateLimited(retryAfter: retryAfter)
            case .serviceUnavailable:
                return .serviceUnavailable
            case .httpStatus(let statusCode):
                return .httpStatus(statusCode)
            case .transport(let nested):
                return .transport(String(describing: nested))
            case .decoding(let nested):
                return .decoding(String(describing: nested))
            case .cancelled:
                return .cancelled
            }
        case is CancellationError:
            return .cancelled
        default:
            return .transport(String(describing: error))
        }
    }

    private static func resolveIdentifier(
        for key: StorageKey,
        prefix: String,
        defaults: UserDefaults
    ) -> String {
        if let existing = defaults.string(forKey: key.rawValue),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let identifier = "\(prefix)-\(UUID().uuidString)"
        defaults.set(identifier, forKey: key.rawValue)
        return identifier
    }
}

private extension TaskSyncResolvedTaskVersion {
    init(dto: TaskSyncTaskDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            categoryID: dto.categoryID,
            isCompleted: dto.isCompleted,
            phase: dto.phase,
            version: dto.version,
            updatedAt: dto.updatedAt
        )
    }
}

private extension TaskSyncTaskDTO {
    init(operation: TaskSyncOperationEntity) {
        self.init(
            id: operation.entityID,
            title: operation.title,
            categoryID: operation.categoryID,
            isCompleted: operation.isCompleted,
            phase: operation.phase,
            version: operation.entityVersion,
            updatedAt: operation.lastModified
        )
    }
}
