import XCTest
@testable import arrival_uk

final class CollaborationSyncEngineTests: XCTestCase {
    private enum TestError: Error {
        case disconnected
    }

    private struct Harness {
        let suiteName: String
        let defaults: UserDefaults

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    actor TestRealtimeTransport: CollaborationRealtimeTransport {
        typealias SendHook = @Sendable (CollaborationRealtimeEnvelope, TestRealtimeTransport) async -> Void

        private var queuedEnvelopes: [CollaborationRealtimeEnvelope] = []
        private var receiveContinuation: CheckedContinuation<CollaborationRealtimeEnvelope, Error>?
        private var receiveError: Error?
        private var sentEnvelopes: [CollaborationRealtimeEnvelope] = []
        private var connectCount = 0
        private var disconnectCount = 0
        private let sendHook: SendHook?

        init(sendHook: SendHook? = nil) {
            self.sendHook = sendHook
        }

        func connect(url: URL) async throws {
            connectCount += 1
        }

        func disconnect() async {
            disconnectCount += 1
        }

        func send(_ envelope: CollaborationRealtimeEnvelope) async throws {
            sentEnvelopes.append(envelope)
            if let sendHook {
                await sendHook(envelope, self)
            }
        }

        func receive() async throws -> CollaborationRealtimeEnvelope {
            if let receiveError {
                self.receiveError = nil
                throw receiveError
            }

            if !queuedEnvelopes.isEmpty {
                return queuedEnvelopes.removeFirst()
            }

            return try await withCheckedThrowingContinuation { continuation in
                receiveContinuation = continuation
            }
        }

        func enqueue(_ envelope: CollaborationRealtimeEnvelope) {
            if let receiveContinuation {
                self.receiveContinuation = nil
                receiveContinuation.resume(returning: envelope)
            } else {
                queuedEnvelopes.append(envelope)
            }
        }

        func failNextReceive(_ error: Error) {
            if let receiveContinuation {
                self.receiveContinuation = nil
                receiveContinuation.resume(throwing: error)
            } else {
                receiveError = error
            }
        }

        func sent() -> [CollaborationRealtimeEnvelope] {
            sentEnvelopes
        }

        func connectAttempts() -> Int {
            connectCount
        }
    }

    private func makeHarness() throws -> Harness {
        let suiteName = "arrivaluk.collaboration.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create isolated UserDefaults suite.")
        }
        return Harness(suiteName: suiteName, defaults: defaults)
    }

    @MainActor
    private func makeEngine(
        harness: Harness,
        transport: TestRealtimeTransport,
        realtimeEnabled: Bool = true,
        sleepProvider: @escaping @Sendable (TimeInterval) async -> Void = { _ in },
        maximumReconnectAttempts: Int = 10
    ) -> CollaborationSyncEngine {
        CollaborationSyncEngine(
            defaults: harness.defaults,
            transport: transport,
            websocketURL: URL(string: "wss://example.com/realtime"),
            realtimeEnabled: realtimeEnabled,
            sleepProvider: sleepProvider,
            jitterProvider: { 1.0 },
            notificationCenter: NotificationCenter(),
            maximumReconnectAttempts: maximumReconnectAttempts
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

    private func waitUntilAsync(
        timeoutSeconds: TimeInterval = 2.0,
        pollNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return await condition()
    }

    private static func snapshotEnvelope(
        roomID: String,
        requestID: String?,
        sequenceNumber: Int64,
        tasks: [CollaborativeTaskRecord] = [],
        historyEvicted: Bool = false
    ) -> CollaborationRealtimeEnvelope {
        CollaborationRealtimeEnvelope(
            type: "snapshot",
            roomID: roomID,
            requestID: requestID,
            operationID: UUID().uuidString,
            sequenceNumber: sequenceNumber,
            historyEvicted: historyEvicted,
            task: nil,
            tasks: nil,
            presence: nil,
            snapshot: CollaborationRoomSnapshot(
                roomID: roomID,
                sequenceNumber: sequenceNumber,
                tasks: tasks,
                presence: [],
                historyEvicted: historyEvicted
            )
        )
    }

    private static func taskEnvelope(
        roomID: String,
        sequenceNumber: Int64,
        operationID: String,
        taskID: String,
        title: String
    ) -> CollaborationRealtimeEnvelope {
        CollaborationRealtimeEnvelope(
            type: "task_update",
            roomID: roomID,
            requestID: nil,
            operationID: operationID,
            sequenceNumber: sequenceNumber,
            historyEvicted: false,
            task: CollaborativeTaskRecord(
                id: taskID,
                title: title,
                categoryID: "category",
                status: .completed,
                isTier1Urgent: false,
                lastEditedBy: "peer",
                timestamp: LamportTimestamp(counter: sequenceNumber, actorID: "peer"),
                completedAtMillis: 1_700_100_000_000
            ),
            tasks: nil,
            presence: nil,
            snapshot: nil
        )
    }

    private static func presenceEnvelope(
        roomID: String,
        sequenceNumber: Int64,
        operationID: String,
        userID: String,
        displayName: String,
        isActive: Bool
    ) -> CollaborationRealtimeEnvelope {
        CollaborationRealtimeEnvelope(
            type: "presence",
            roomID: roomID,
            requestID: nil,
            operationID: operationID,
            sequenceNumber: sequenceNumber,
            historyEvicted: false,
            task: nil,
            tasks: nil,
            presence: CollaborationSyncEngine.PresenceSignal(
                userID: userID,
                displayName: displayName,
                isActive: isActive,
                viewingTaskID: nil,
                sentAtMillis: 1_700_100_000_000
            ),
            snapshot: nil
        )
    }

    @MainActor
    func testRealtimeDisabledDoesNotAttemptConnection() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport()
        let engine = makeEngine(
            harness: harness,
            transport: transport,
            realtimeEnabled: false
        )

        engine.configureIfNeeded()

        let didSetFailedState = await waitUntil {
            engine.connectionStateForTesting() == .failed(reason: "collaboration_realtime_disabled")
        }
        let connectAttempts = await transport.connectAttempts()

        XCTAssertTrue(didSetFailedState)
        XCTAssertEqual(connectAttempts, 0)
    }

    @MainActor
    func testMessagesFromRoomANotDeliveredToRoomBSubscriber() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()

        let connected = await waitUntil { engine.connectionStateForTesting() == .connected }
        XCTAssertTrue(connected)

        engine.joinRoom("roomB")
        let joined = await waitUntil { engine.activeRoomIDsForTesting().contains("roomB") }
        XCTAssertTrue(joined)

        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 1,
                operationID: "roomA-op-1",
                taskID: "roomA-task",
                title: "Room A task"
            )
        )
        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomB",
                sequenceNumber: 1,
                operationID: "roomB-op-1",
                taskID: "roomB-task",
                title: "Room B task"
            )
        )

        XCTAssertEqual(engine.taskRecordsForTesting(roomID: "roomA").map(\.id), ["roomA-task"])
        XCTAssertEqual(engine.taskRecordsForTesting(roomID: "roomB").map(\.id), ["roomB-task"])
    }

    @MainActor
    func testReconnectResubscribesToAllPreviousRooms() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        engine.joinRoom("roomB")
        _ = await waitUntil { engine.activeRoomIDsForTesting() == Set(["roomA", "roomB"]) }

        await transport.failNextReceive(TestError.disconnected)
        let reconnected = await waitUntilAsync {
            let attempts = await transport.connectAttempts()
            let isConnected = await MainActor.run {
                engine.connectionStateForTesting() == .connected
            }
            return attempts >= 2 && isConnected
        }
        XCTAssertTrue(reconnected)

        let sent = await transport.sent().filter { $0.type == "join" }
        let joinedRooms = sent.map(\.roomID)
        XCTAssertGreaterThanOrEqual(joinedRooms.filter { $0 == "roomA" }.count, 2)
        XCTAssertGreaterThanOrEqual(joinedRooms.filter { $0 == "roomB" }.count, 2)
    }

    @MainActor
    func testStateResyncRequestedAfterReconnectWithSequenceGap() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 1
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 3,
                operationID: "gap-op",
                taskID: "gap-task",
                title: "Gap task"
            )
        )

        let requested = await waitUntilAsync {
            let sent = await transport.sent()
            return sent.contains {
                $0.type == "resync_request" && $0.roomID == "roomA" && $0.sequenceNumber == 1
            }
        }
        XCTAssertTrue(requested)
    }

    @MainActor
    func testFullStateFetchOnHistoryEviction() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 1,
                        tasks: [
                            CollaborativeTaskRecord(
                                id: "old-task",
                                title: "Old",
                                categoryID: "category",
                                status: .completed,
                                isTier1Urgent: false,
                                lastEditedBy: "peer",
                                timestamp: LamportTimestamp(counter: 1, actorID: "peer"),
                                completedAtMillis: 1_700_100_000_000
                            )
                        ]
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await engine.handleIncomingEnvelopeForTesting(
            Self.snapshotEnvelope(
                roomID: "roomA",
                requestID: nil,
                sequenceNumber: 5,
                tasks: [
                    CollaborativeTaskRecord(
                        id: "new-task",
                        title: "New",
                        categoryID: "category",
                        status: .completed,
                        isTier1Urgent: false,
                        lastEditedBy: "peer",
                        timestamp: LamportTimestamp(counter: 5, actorID: "peer"),
                        completedAtMillis: 1_700_100_000_000
                    )
                ],
                historyEvicted: true
            )
        )

        XCTAssertEqual(engine.taskRecordsForTesting(roomID: "roomA").map(\.id), ["new-task"])
        XCTAssertEqual(engine.lastSequenceForTesting(roomID: "roomA"), 5)
    }

    @MainActor
    func testOutOfOrderOperationsBufferedAndReordered() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 2,
                operationID: "op-2",
                taskID: "task-2",
                title: "Second"
            )
        )
        XCTAssertEqual(engine.taskRecordsForTesting(roomID: "roomA"), [])

        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 1,
                operationID: "op-1",
                taskID: "task-1",
                title: "First"
            )
        )

        XCTAssertEqual(Set(engine.taskRecordsForTesting(roomID: "roomA").map(\.id)), Set(["task-1", "task-2"]))
        XCTAssertEqual(engine.lastSequenceForTesting(roomID: "roomA"), 2)
    }

    @MainActor
    func testDuplicateOperationIdDropped() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(harness: harness, transport: transport)
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 1,
                operationID: "duplicate-op",
                taskID: "task-1",
                title: "Original"
            )
        )
        await engine.handleIncomingEnvelopeForTesting(
            Self.taskEnvelope(
                roomID: "roomA",
                sequenceNumber: 2,
                operationID: "duplicate-op",
                taskID: "task-1",
                title: "Should Drop"
            )
        )

        XCTAssertEqual(engine.taskRecordsForTesting(roomID: "roomA").first?.title, "Original")
        XCTAssertEqual(engine.lastSequenceForTesting(roomID: "roomA"), 1)
    }

    @MainActor
    func testPresenceClearedAfterPeerDisconnect() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(
            harness: harness,
            transport: transport,
            sleepProvider: { _ in }
        )
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await engine.handleIncomingEnvelopeForTesting(
            Self.presenceEnvelope(
                roomID: "roomA",
                sequenceNumber: 1,
                operationID: "presence-1",
                userID: "peer-1",
                displayName: "Peer",
                isActive: true
            )
        )
        XCTAssertTrue(engine.collaboratorIsActive)

        await engine.handleIncomingEnvelopeForTesting(
            CollaborationRealtimeEnvelope(
                type: "peer_disconnected",
                roomID: "roomA",
                requestID: nil,
                operationID: "disconnect-1",
                sequenceNumber: 2,
                historyEvicted: false,
                task: nil,
                tasks: nil,
                presence: CollaborationSyncEngine.PresenceSignal(
                    userID: "peer-1",
                    displayName: "Peer",
                    isActive: false,
                    viewingTaskID: nil,
                    sentAtMillis: 1_700_100_000_001
                ),
                snapshot: nil
            )
        )
        await Task.yield()

        XCTAssertFalse(engine.collaboratorIsActive)
    }

    func testReconnectBackoffDoesNotExceedCap() {
        XCTAssertEqual(
            CollaborationSyncEngine.reconnectDelaySeconds(forAttempt: 20, jitter: 1.0),
            60
        )
    }

    @MainActor
    func testForegroundTransitionTriggerReconnect() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let transport = TestRealtimeTransport { envelope, transport in
            if envelope.type == "join" {
                await transport.enqueue(
                    Self.snapshotEnvelope(
                        roomID: envelope.roomID,
                        requestID: envelope.requestID,
                        sequenceNumber: 0
                    )
                )
            }
        }
        let engine = makeEngine(
            harness: harness,
            transport: transport,
            maximumReconnectAttempts: 0
        )
        engine.setJourneyID("roomA")
        engine.configureIfNeeded()
        _ = await waitUntil { engine.connectionStateForTesting() == .connected }

        await transport.failNextReceive(TestError.disconnected)
        let failed = await waitUntil {
            if case .failed = engine.connectionStateForTesting() {
                return true
            }
            return false
        }
        XCTAssertTrue(failed)

        await engine.triggerForegroundReconnectForTesting()
        let reconnected = await waitUntilAsync {
            let attempts = await transport.connectAttempts()
            let isConnected = await MainActor.run {
                engine.connectionStateForTesting() == .connected
            }
            return attempts >= 2 && isConnected
        }
        XCTAssertTrue(reconnected)
    }
}
