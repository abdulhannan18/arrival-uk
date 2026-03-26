import XCTest
import SwiftData
@testable import arrival_uk

final class TaskSyncStoreTests: XCTestCase {
    private enum TestError: Error {
        case offline
        case droppedAfterApply
    }

    private struct StoreHarness {
        let suiteName: String
        let defaults: UserDefaults
        let storeURL: URL

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
    }

    @MainActor
    private final class ScriptedTransport: TaskSyncTransport {
        typealias Handler = @MainActor @Sendable (TaskSyncBatchRequest, TaskSyncRequestTimeouts, Int) async throws -> TaskSyncBatchResponse

        private let handler: Handler
        private var requests: [TaskSyncBatchRequest] = []
        private var timeouts: [TaskSyncRequestTimeouts] = []
        private var callCount = 0

        init(handler: @escaping Handler) {
            self.handler = handler
        }

        func send(
            request: TaskSyncBatchRequest,
            timeout: TaskSyncRequestTimeouts
        ) async throws -> TaskSyncBatchResponse {
            callCount += 1
            requests.append(request)
            timeouts.append(timeout)
            return try await handler(request, timeout, callCount)
        }

        func capturedRequests() -> [TaskSyncBatchRequest] {
            requests
        }

        func capturedTimeouts() -> [TaskSyncRequestTimeouts] {
            timeouts
        }
    }

    @MainActor
    private final class DelayRecorder {
        private var values: [TimeInterval] = []

        func append(_ value: TimeInterval) {
            values.append(value)
        }

        func captured() -> [TimeInterval] {
            values
        }
    }

    @MainActor
    private final class SuspendedSleepGate {
        private var values: [TimeInterval] = []
        private var continuation: CheckedContinuation<Void, Never>?

        func sleep(_ value: TimeInterval) async {
            values.append(value)
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }

        func captured() -> [TimeInterval] {
            values
        }
    }

    @MainActor
    private final class ApplyRecorder {
        private var applyCounts: [String: Int] = [:]
        private var cachedResponses: [String: TaskSyncBatchResponse] = [:]

        func applyOrReplay(
            request: TaskSyncBatchRequest,
            serverTimestamp: Date
        ) throws -> TaskSyncBatchResponse {
            let operation = TaskSyncStoreTests.firstOperation(in: request)
            if let cachedResponse = cachedResponses[operation.operationId] {
                return cachedResponse
            }

            applyCounts[operation.operationId, default: 0] += 1
            let response = TaskSyncStoreTests.acknowledgedResponse(
                for: operation,
                serverTimestamp: serverTimestamp
            )
            cachedResponses[operation.operationId] = response
            throw TaskSyncTransportError.transport(TestError.droppedAfterApply)
        }

        func applyCount(for operationID: String) -> Int {
            applyCounts[operationID, default: 0]
        }
    }

    private func makeHarness() throws -> StoreHarness {
        let suiteName = "arrivaluk.tasksync.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create isolated UserDefaults suite.")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("arrivaluk-task-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return StoreHarness(
            suiteName: suiteName,
            defaults: defaults,
            storeURL: directory.appendingPathComponent("TaskSync.sqlite")
        )
    }

    @MainActor
    private func makeStore(
        harness: StoreHarness,
        transport: any TaskSyncTransport,
        sleepProvider: @escaping @Sendable (TimeInterval) async -> Void = { _ in },
        jitterProvider: @escaping @Sendable () -> Double = { 1.0 }
    ) throws -> TaskSyncStore {
        TaskSyncStore(
            defaults: harness.defaults,
            configuration: ModelConfiguration(url: harness.storeURL),
            transport: transport,
            sleepProvider: sleepProvider,
            jitterProvider: jitterProvider
        )
    }

    @MainActor
    private func waitUntil(
        timeoutSeconds: TimeInterval = 2.0,
        pollNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @MainActor @Sendable () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }

    @MainActor
    private static func firstOperation(in request: TaskSyncBatchRequest) -> TaskSyncOperationRequest {
        guard let operation = request.operations.first else {
            preconditionFailure("Expected a queued task sync operation.")
        }
        return operation
    }

    @MainActor
    private static func acknowledgedResponse(
        for operation: TaskSyncOperationRequest,
        serverTimestamp: Date
    ) -> TaskSyncBatchResponse {
        TaskSyncBatchResponse(
            results: [
                TaskSyncOperationResult(
                    operationId: operation.operationId,
                    accepted: true,
                    serverVersion: operation.entityVersion,
                    serverTimestamp: serverTimestamp,
                    conflictPayload: nil
                )
            ]
        )
    }

    @MainActor
    private static func conflictResponse(
        for operation: TaskSyncOperationRequest,
        remoteVersion: TaskSyncTaskDTO,
        serverTimestamp: Date
    ) -> TaskSyncBatchResponse {
        TaskSyncBatchResponse(
            results: [
                TaskSyncOperationResult(
                    operationId: operation.operationId,
                    accepted: false,
                    serverVersion: remoteVersion.version,
                    serverTimestamp: serverTimestamp,
                    conflictPayload: remoteVersion
                )
            ]
        )
    }

    @MainActor
    func testSyncSucceedsOnFirstAttempt() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let serverTimestamp = Date(timeIntervalSince1970: 1_700_000_100)
        let transport = ScriptedTransport { request, _, _ in
            let operation = Self.firstOperation(in: request)
            return Self.acknowledgedResponse(for: operation, serverTimestamp: serverTimestamp)
        }
        let store = try makeStore(harness: harness, transport: transport)

        store.recordCompletion(
            taskID: "task.sync.success",
            title: "Book accommodation",
            categoryID: "housing",
            phase: 1,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = transport.capturedRequests()
        let timeouts = transport.capturedTimeouts()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(timeouts.count, 1)
        XCTAssertEqual(timeouts.first?.connectTimeout, 10)
        XCTAssertEqual(timeouts.first?.requestTimeout, 30)
        XCTAssertEqual(requests.first?.operations.first?.entityVersion, 1)

        let versions = store.taskVersionsForTesting()
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.id, "task.sync.success")
        XCTAssertEqual(versions.first?.version, 1)
        XCTAssertEqual(versions.first?.updatedAt, serverTimestamp)
        XCTAssertEqual(store.pendingOperationsForTesting(), [])
        XCTAssertEqual(store.syncState, .idle)
    }

    @MainActor
    func testSyncRetriesOnNetworkFailureWithBackoff() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let delayRecorder = DelayRecorder()
        let serverTimestamp = Date(timeIntervalSince1970: 1_700_000_200)
        let transport = ScriptedTransport { request, _, callCount in
            let operation = Self.firstOperation(in: request)
            if callCount < 3 {
                throw TaskSyncTransportError.transport(TestError.offline)
            }
            return Self.acknowledgedResponse(for: operation, serverTimestamp: serverTimestamp)
        }
        let store = try makeStore(
            harness: harness,
            transport: transport,
            sleepProvider: { delay in
                await MainActor.run {
                    delayRecorder.append(delay)
                }
            },
            jitterProvider: { 1.0 }
        )

        store.recordCompletion(
            taskID: "task.sync.retry",
            title: "Open a bank account",
            categoryID: "banking",
            phase: 1,
            completedAt: Date(timeIntervalSince1970: 1_700_000_150)
        )

        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = transport.capturedRequests()
        let delays = delayRecorder.captured()
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(delays, [1.0, 2.0])
        XCTAssertEqual(store.syncState, .idle)
    }

    @MainActor
    func testSyncDoesNotRetryOn409Conflict() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let localTimestamp = Date(timeIntervalSince1970: 1_700_000_300)
        let remoteTimestamp = Date(timeIntervalSince1970: 1_700_000_360)
        let transport = ScriptedTransport { request, _, _ in
            let operation = Self.firstOperation(in: request)
            let remoteVersion = TaskSyncTaskDTO(
                id: operation.entityId,
                title: "Server copy",
                categoryID: "visa",
                isCompleted: true,
                phase: 2,
                version: 3,
                updatedAt: remoteTimestamp
            )
            throw TaskSyncTransportError.conflict(
                Self.conflictResponse(
                    for: operation,
                    remoteVersion: remoteVersion,
                    serverTimestamp: remoteTimestamp
                )
            )
        }
        let store = try makeStore(harness: harness, transport: transport)

        store.recordCompletion(
            taskID: "task.sync.conflict.server",
            title: "Local copy",
            categoryID: "visa",
            phase: 1,
            completedAt: localTimestamp
        )

        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = transport.capturedRequests()
        XCTAssertEqual(requests.count, 1)

        let versions = store.taskVersionsForTesting()
        XCTAssertEqual(versions.first?.title, "Server copy")
        XCTAssertEqual(versions.first?.version, 3)
        XCTAssertEqual(versions.first?.updatedAt, remoteTimestamp)
        XCTAssertEqual(store.syncState, .idle)
    }

    @MainActor
    func testOfflineQueuePersistsAcrossAppRestart() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let failingTransport = ScriptedTransport { _, _, _ in
            throw TaskSyncTransportError.transport(TestError.offline)
        }
        let firstStore = try makeStore(
            harness: harness,
            transport: failingTransport,
            sleepProvider: { _ in },
            jitterProvider: { 1.0 }
        )

        firstStore.recordCompletion(
            taskID: "task.sync.restart",
            title: "Get a SIM card",
            categoryID: "settling-in",
            phase: 2,
            completedAt: Date(timeIntervalSince1970: 1_700_000_400)
        )

        let queued = await waitUntil {
            firstStore.pendingOperationsForTesting().count == 1
        }
        XCTAssertTrue(queued)

        firstStore.cancelInFlightSync(reason: "test_restart_cleanup")
        await Task.yield()

        let successTransport = ScriptedTransport { request, _, _ in
            let operation = Self.firstOperation(in: request)
            return Self.acknowledgedResponse(
                for: operation,
                serverTimestamp: Date(timeIntervalSince1970: 1_700_000_450)
            )
        }
        let restartedStore = try makeStore(harness: harness, transport: successTransport)

        XCTAssertEqual(restartedStore.pendingUpdateCount, 1)
        await restartedStore.flushPendingUpdatesIfNeeded(reason: "restart", force: true)
        let drained = await waitUntil { restartedStore.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = successTransport.capturedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(restartedStore.pendingOperationsForTesting(), [])
    }

    @MainActor
    func testConflictResolutionSelectsCorrectVersion() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let localTimestamp = Date(timeIntervalSince1970: 1_700_000_520)
        let remoteTimestamp = Date(timeIntervalSince1970: 1_700_000_480)
        let transport = ScriptedTransport { request, _, callCount in
            let operation = Self.firstOperation(in: request)
            if callCount == 1 {
                let remoteVersion = TaskSyncTaskDTO(
                    id: operation.entityId,
                    title: "Remote copy",
                    categoryID: "documents",
                    isCompleted: true,
                    phase: 1,
                    version: 1,
                    updatedAt: remoteTimestamp
                )
                throw TaskSyncTransportError.conflict(
                    Self.conflictResponse(
                        for: operation,
                        remoteVersion: remoteVersion,
                        serverTimestamp: remoteTimestamp
                    )
                )
            }
            return Self.acknowledgedResponse(
                for: operation,
                serverTimestamp: Date(timeIntervalSince1970: 1_700_000_560)
            )
        }
        let store = try makeStore(harness: harness, transport: transport)
        store.conflictResolutionStrategy = .clientWins

        store.recordCompletion(
            taskID: "task.sync.conflict.local",
            title: "Local wins",
            categoryID: "documents",
            phase: 1,
            completedAt: localTimestamp
        )

        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = transport.capturedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].operations.first?.entityVersion, 1)
        XCTAssertEqual(requests[1].operations.first?.entityVersion, 2)
        XCTAssertEqual(store.lastConflictEvent?.localVersion.title, "Local wins")
        XCTAssertEqual(store.taskVersionsForTesting().first?.version, 2)
    }

    @MainActor
    func testIdempotencyKeyPreventsDoubleApplication() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let applyRecorder = ApplyRecorder()
        let transport = ScriptedTransport { request, _, _ in
            try applyRecorder.applyOrReplay(
                request: request,
                serverTimestamp: Date(timeIntervalSince1970: 1_700_000_610)
            )
        }
        let store = try makeStore(
            harness: harness,
            transport: transport,
            sleepProvider: { _ in },
            jitterProvider: { 1.0 }
        )

        store.recordCompletion(
            taskID: "task.sync.idempotent",
            title: "Collect BRP",
            categoryID: "immigration",
            phase: 1,
            completedAt: Date(timeIntervalSince1970: 1_700_000_600)
        )

        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)

        let requests = transport.capturedRequests()
        XCTAssertEqual(requests.count, 2)
        let operationID = try XCTUnwrap(requests.first?.operations.first?.operationId)
        let applyCount = applyRecorder.applyCount(for: operationID)
        XCTAssertEqual(applyCount, 1)
    }

    @MainActor
    func testSyncStateMachineCannotEnterImpossibleState() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let sleepGate = SuspendedSleepGate()
        let transport = ScriptedTransport { request, _, callCount in
            let operation = Self.firstOperation(in: request)
            if callCount == 1 {
                throw TaskSyncTransportError.transport(TestError.offline)
            }
            return Self.acknowledgedResponse(
                for: operation,
                serverTimestamp: Date(timeIntervalSince1970: 1_700_000_710)
            )
        }
        let store = try makeStore(
            harness: harness,
            transport: transport,
            sleepProvider: { delay in
                await sleepGate.sleep(delay)
            },
            jitterProvider: { 1.0 }
        )

        store.recordCompletion(
            taskID: "task.sync.state",
            title: "Register with GP",
            categoryID: "health",
            phase: 2,
            completedAt: Date(timeIntervalSince1970: 1_700_000_700)
        )

        let reachedRetryState = await waitUntil {
            if case .pendingRetry(let retryCount, _) = store.syncState {
                return retryCount == 1
            }
            return false
        }
        XCTAssertTrue(reachedRetryState)

        sleepGate.release()
        let drained = await waitUntil { store.pendingUpdateCount == 0 }
        XCTAssertTrue(drained)
        let delays = sleepGate.captured()
        XCTAssertEqual(delays, [1.0])
        XCTAssertEqual(store.syncState, .idle)
    }

    @MainActor
    func testConcurrentWritesSerializeOnQueue() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = ScriptedTransport { _, _, _ in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            throw CancellationError()
        }
        let store = try makeStore(harness: harness, transport: transport)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<8 {
                group.addTask { @MainActor in
                    store.recordCompletion(
                        taskID: "task.sync.concurrent",
                        title: "Concurrent write \(index)",
                        categoryID: "banking",
                        phase: 1,
                        completedAt: Date(timeIntervalSince1970: 1_700_000_800 + Double(index))
                    )
                }
            }
        }

        let queued = await waitUntil { store.pendingOperationsForTesting().count == 8 }
        XCTAssertTrue(queued)

        let operations = store.pendingOperationsForTesting()
        XCTAssertEqual(operations.map(\.ordinal), Array(1...8).map(Int64.init))
        XCTAssertEqual(operations.map(\.entityVersion), Array(1...8))

        store.cancelInFlightSync(reason: "test_concurrent_cleanup")
    }
}
