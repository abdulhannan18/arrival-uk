import Foundation
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum CollaborationConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case reconnecting(attempt: Int)
    case failed(reason: String)
}

nonisolated enum CollaborationRealtimeTransportError: Error, Sendable {
    case notConnected
    case invalidMessage
    case joinTimeout
}

nonisolated struct CollaborationRoomSnapshot: Codable, Sendable {
    let roomID: String
    let sequenceNumber: Int64
    let tasks: [CollaborativeTaskRecord]
    let presence: [CollaborationSyncEngine.PresenceSignal]
    let historyEvicted: Bool
}

nonisolated struct CollaborationRealtimeEnvelope: Codable, Sendable {
    let type: String
    let roomID: String
    let requestID: String?
    let operationID: String?
    let sequenceNumber: Int64
    let historyEvicted: Bool
    let task: CollaborativeTaskRecord?
    let tasks: [CollaborativeTaskRecord]?
    let presence: CollaborationSyncEngine.PresenceSignal?
    let snapshot: CollaborationRoomSnapshot?
}

nonisolated protocol CollaborationRealtimeTransport {
    func connect(url: URL) async throws
    func disconnect() async
    func send(_ envelope: CollaborationRealtimeEnvelope) async throws
    func receive() async throws -> CollaborationRealtimeEnvelope
}

@available(iOS 17.0, *)
private actor CollaborationWebSocketTransport: CollaborationRealtimeTransport {
    private var websocketTask: URLSessionWebSocketTask?

    func connect(url: URL) async throws {
        await disconnect()
        let task = URLSession.shared.webSocketTask(with: url)
        websocketTask = task
        task.resume()
    }

    func disconnect() async {
        websocketTask?.cancel(with: .goingAway, reason: nil)
        websocketTask = nil
    }

    func send(_ envelope: CollaborationRealtimeEnvelope) async throws {
        guard let websocketTask else {
            throw CollaborationRealtimeTransportError.notConnected
        }

        let data = try JSONEncoder().encode(envelope)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CollaborationRealtimeTransportError.invalidMessage
        }
        try await websocketTask.send(.string(text))
    }

    func receive() async throws -> CollaborationRealtimeEnvelope {
        guard let websocketTask else {
            throw CollaborationRealtimeTransportError.notConnected
        }

        let message = try await websocketTask.receive()
        let data: Data
        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else {
                throw CollaborationRealtimeTransportError.invalidMessage
            }
            data = textData
        case .data(let payload):
            data = payload
        @unknown default:
            throw CollaborationRealtimeTransportError.invalidMessage
        }

        return try JSONDecoder().decode(CollaborationRealtimeEnvelope.self, from: data)
    }
}

/*
 Collaboration remediation notes:
 1. Intended mechanism: room-scoped collaborative task sync using Lamport timestamps inside the CRDT
    plus a server-issued per-room sequence cursor for ordered delivery and reconnect resync.
 2. Broken behavior before this change: inbound messages were accepted without room validation, the
    receive loop died permanently on the first socket error, reconnect did not re-authenticate or
    re-subscribe, and out-of-order / duplicate operations could be applied immediately.
 3. Backend contract required by this implementation: the realtime server must scope every message
    by room, validate room membership server-side, answer `join` with a full snapshot + sequence
    cursor, and answer `resync_request` with either replayable deltas or a `historyEvicted` snapshot.
 */
@available(iOS 17.0, *)
@MainActor
@Observable
final class CollaborationSyncEngine {
    static let shared = CollaborationSyncEngine()

    nonisolated struct PresenceSignal: Codable, Hashable, Equatable, Sendable {
        var userID: String
        var displayName: String
        var isActive: Bool
        var viewingTaskID: String?
        var sentAtMillis: Int64
    }

    private struct PersistedRoomState: Codable, Equatable {
        var taskSet: CollaborativeTaskLWWSet
        var lastSequence: Int64
    }

    private struct RoomRuntimeState {
        var taskSet: CollaborativeTaskLWWSet
        var lastSequence: Int64
        var completionOverlay: [String: Date]
        var bufferedEnvelopes: [Int64: CollaborationRealtimeEnvelope]
        var seenOperationIDs: [String]
        var presenceByUserID: [String: PresenceSignal]
    }

    private let actorIDKey = StorageKey.collaborationActorID.rawValue
    private let lamportCounterKey = StorageKey.collaborationLamportCounter.rawValue
    private let journeyIDKey = StorageKey.collaborationJourneyID.rawValue
    private let heartbeatKey = StorageKey.collaborationPresenceHeartbeat.rawValue
    private let roomStateKey = StorageKey.collaborationRoomState.rawValue
    private let activeRoomsKey = StorageKey.collaborationActiveRoomIDs.rawValue

    private let defaults: UserDefaults
    private let transport: any CollaborationRealtimeTransport
    private let realtimeEnabled: Bool
    private let websocketURL: URL?
    private let nowProvider: @Sendable () -> Date
    private let sleepProvider: @Sendable (TimeInterval) async -> Void
    private let jitterProvider: @Sendable () -> Double
    private let notificationCenter: NotificationCenter
    private let maximumReconnectAttempts: Int
    private let joinTimeoutSeconds: TimeInterval = 10
    private let stableConnectionResetSeconds: TimeInterval = 5
    private let presenceGracePeriodSeconds: TimeInterval = 5
    private let seenOperationLimit = 256

    private var actorID: String
    private var lamportCounter: Int64
    private var hasConfigured = false
    private var localViewingTaskID: String?
    private var localDisplayName: String
    private var localPresenceIsActive = false
    private var roomStatesByID: [String: RoomRuntimeState]
    private var activeRoomIDs: Set<String>
    private var receiveLoopTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var pendingResyncRoomIDs: Set<String> = []
    private var preReceiveBuffer: [CollaborationRealtimeEnvelope] = []
    private var reconnectAttempt = 0
    private var connectedAt: Date?
    private var presenceGraceTasks: [String: Task<Void, Never>] = [:]

    var connectionState: CollaborationConnectionState = .disconnected
    var journeyID: String
    var collaboratorDisplayName = "Roommate"
    var collaboratorViewingTaskID: String?
    var collaboratorIsActive = false
    var collaboratorLastHeartbeatAt: Date?

    var presenceBadgeText: String? {
        guard collaboratorIsActive else { return nil }
        if collaboratorViewingTaskID?.isEmpty == false {
            return "\(collaboratorDisplayName) viewing a task"
        }
        return "\(collaboratorDisplayName) active now"
    }

    init(
        defaults: UserDefaults = .standard,
        transport: (any CollaborationRealtimeTransport)? = nil,
        websocketURL: URL? = nil,
        realtimeEnabled: Bool? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        sleepProvider: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        jitterProvider: @escaping @Sendable () -> Double = {
            Double.random(in: 0.5 ... 1.0)
        },
        notificationCenter: NotificationCenter = .default,
        maximumReconnectAttempts: Int = 10
    ) {
        let resolvedRealtimeEnabled = realtimeEnabled ?? AppConfig.collaborationRealtimeEnabled

        self.defaults = defaults
        self.transport = transport ?? CollaborationWebSocketTransport()
        self.realtimeEnabled = resolvedRealtimeEnabled
        self.websocketURL = websocketURL ?? (resolvedRealtimeEnabled ? AppConfig.collaborationWebSocketURL : nil)
        self.nowProvider = nowProvider
        self.sleepProvider = sleepProvider
        self.jitterProvider = jitterProvider
        self.notificationCenter = notificationCenter
        self.maximumReconnectAttempts = maximumReconnectAttempts

        let resolvedActorID: String
        if let persistedActorID = defaults.string(forKey: actorIDKey),
           !persistedActorID.isEmpty {
            resolvedActorID = persistedActorID
        } else {
            resolvedActorID = UUID().uuidString
            defaults.set(resolvedActorID, forKey: actorIDKey)
        }

        let persistedJourneyID = defaults.string(forKey: journeyIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedJourneyID = {
            guard let persistedJourneyID, !persistedJourneyID.isEmpty else {
                return "default-journey"
            }
            return persistedJourneyID
        }()

        let persistedRooms = Self.decodePersistedRooms(from: defaults.data(forKey: roomStateKey))
        let persistedActiveRooms = Set(
            (defaults.array(forKey: activeRoomsKey) as? [String] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        var runtimeRooms: [String: RoomRuntimeState] = [:]
        for (roomID, persisted) in persistedRooms {
            runtimeRooms[roomID] = RoomRuntimeState(
                taskSet: persisted.taskSet,
                lastSequence: persisted.lastSequence,
                completionOverlay: [:],
                bufferedEnvelopes: [:],
                seenOperationIDs: [],
                presenceByUserID: [:]
            )
        }

        actorID = resolvedActorID
        lamportCounter = defaults.object(forKey: lamportCounterKey) as? Int64 ?? 0
        localDisplayName = StudentProfileStore.shared.preferredFirstName ?? "You"
        journeyID = resolvedJourneyID
        activeRoomIDs = persistedActiveRooms.isEmpty ? [resolvedJourneyID] : persistedActiveRooms.union([resolvedJourneyID])
        roomStatesByID = runtimeRooms

        ensureRoomStateExists(for: resolvedJourneyID)
        persistRoomMembership()
        refreshPresenceSummary()
    }

    func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true
        guard realtimeEnabled else {
            connectionState = .failed(reason: "collaboration_realtime_disabled")
            return
        }

        foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleWillEnterForeground()
            }
        }

        Task { @MainActor in
            await connectRealtimeChannelIfNeeded(forceReconnect: false)
        }
    }

    func setJourneyID(_ journeyID: String) {
        let normalized = normalizeRoomID(journeyID)
        guard !normalized.isEmpty else { return }

        self.journeyID = normalized
        defaults.set(normalized, forKey: journeyIDKey)
        joinRoom(normalized)
        refreshPresenceSummary()
    }

    func joinRoom(_ roomID: String) {
        let normalized = normalizeRoomID(roomID)
        guard !normalized.isEmpty else { return }
        ensureRoomStateExists(for: normalized)
        activeRoomIDs.insert(normalized)
        persistRoomMembership()
        guard realtimeEnabled else { return }

        if hasConfigured {
            Task { @MainActor in
                await connectRealtimeChannelIfNeeded(forceReconnect: false)
                if connectionState == .connected {
                    do {
                        try await sendJoinRequest(for: normalized)
                    } catch {
                        CrashReporter.record(error: error, context: "collaboration_join_\(normalized)")
                        await handleUnexpectedDisconnect(reason: "join_failed_\(normalized)")
                    }
                }
            }
        }
    }

    func leaveRoom(_ roomID: String) {
        let normalized = normalizeRoomID(roomID)
        guard activeRoomIDs.contains(normalized) else { return }
        guard activeRoomIDs.count > 1 || normalized != journeyID else { return }

        activeRoomIDs.remove(normalized)
        let lastSequence = roomStatesByID[normalized]?.lastSequence ?? 0
        roomStatesByID.removeValue(forKey: normalized)
        pendingResyncRoomIDs.remove(normalized)
        cancelPresenceGraceTasks(for: normalized)
        persistRoomsState()
        persistRoomMembership()

        if connectionState == .connected {
            Task { @MainActor in
                try? await transport.send(
                    CollaborationRealtimeEnvelope(
                        type: "leave",
                        roomID: normalized,
                        requestID: nil,
                        operationID: UUID().uuidString,
                        sequenceNumber: lastSequence,
                        historyEvicted: false,
                        task: nil,
                        tasks: nil,
                        presence: currentPresenceSignal(),
                        snapshot: nil
                    )
                )
            }
        }

        if journeyID == normalized, let fallbackRoom = activeRoomIDs.sorted().first {
            journeyID = fallbackRoom
            defaults.set(fallbackRoom, forKey: journeyIDKey)
        }
        refreshPresenceSummary()
    }

    func markLocalPresence(isActive: Bool) {
        localPresenceIsActive = isActive
        if !isActive {
            localViewingTaskID = nil
        }

        defaults.set(nowProvider(), forKey: heartbeatKey)
        guard realtimeEnabled else { return }

        if isActive {
            startPresenceHeartbeatIfNeeded()
            Task { @MainActor in
                await connectRealtimeChannelIfNeeded(forceReconnect: false)
                await sendCurrentPresence()
            }
        } else {
            stopPresenceHeartbeat()
            Task { @MainActor in
                await sendCurrentPresence()
            }
        }
    }

    func publishViewing(taskID: String?) {
        localViewingTaskID = taskID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard realtimeEnabled else { return }
        Task { @MainActor in
            await sendCurrentPresence()
        }
    }

    func registerLocalCompletion(
        taskID: String,
        title: String,
        categoryID: String,
        isTier1Urgent: Bool,
        completedAt: Date = .now
    ) {
        let trimmedID = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        ensureRoomStateExists(for: journeyID)
        var roomState = roomStatesByID[journeyID] ?? Self.emptyRoomState()
        let timestamp = nextLamportTimestamp()
        let completionMillis = epochMillis(completedAt)
        let record = CollaborativeTaskRecord(
            id: trimmedID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .completed,
            isTier1Urgent: isTier1Urgent,
            lastEditedBy: actorID,
            timestamp: timestamp,
            completedAtMillis: completionMillis
        )
        roomState.taskSet.upsert(record)
        roomState.completionOverlay[trimmedID] = completedAt
        roomStatesByID[journeyID] = roomState
        persistRoomsState()

        Task { @MainActor in
            await sendTaskUpdate(record, roomID: journeyID)
        }
    }

    func consumeCompletionOverlay() -> [String: Date] {
        ensureRoomStateExists(for: journeyID)
        var roomState = roomStatesByID[journeyID] ?? Self.emptyRoomState()
        let snapshot = roomState.completionOverlay
        roomState.completionOverlay = [:]
        roomStatesByID[journeyID] = roomState
        return snapshot
    }

    func handleSilentPushPayload(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard let rawType = userInfo["type"] as? String else { return false }
        let normalizedType = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedType == "collaboration_sync" || normalizedType == "collab_sync" else {
            return false
        }

        let roomID = normalizeRoomID(
            (userInfo["journeyID"] as? String)
                ?? (userInfo["roomID"] as? String)
                ?? (userInfo["roomId"] as? String)
        )
        guard !roomID.isEmpty, activeRoomIDs.contains(roomID) else { return false }

        let records = decodeTaskRecords(from: userInfo["tasks"])
        let didMerge = mergeRemote(records: records, roomID: roomID)
        if didMerge {
            notificationCenter.post(name: .didReceiveSilentCollaborationSync, object: nil, userInfo: userInfo)
        }
        return didMerge
    }

    func mergeRemote(records: [CollaborativeTaskRecord]) -> Bool {
        mergeRemote(records: records, roomID: journeyID)
    }

    func mergeRemote(records: [CollaborativeTaskRecord], roomID: String) -> Bool {
        let normalizedRoomID = normalizeRoomID(roomID)
        guard !normalizedRoomID.isEmpty else { return false }
        ensureRoomStateExists(for: normalizedRoomID)

        var roomState = roomStatesByID[normalizedRoomID] ?? Self.emptyRoomState()
        let beforeEntries = Dictionary(uniqueKeysWithValues: roomState.taskSet.resolvedEntries.map { ($0.id, $0) })
        for record in records {
            roomState.taskSet.upsert(record)
        }
        let didMutate = updateCompletionOverlay(
            roomID: normalizedRoomID,
            beforeEntries: beforeEntries,
            roomState: &roomState
        )
        roomStatesByID[normalizedRoomID] = roomState
        if didMutate {
            persistRoomsState()
        }
        refreshPresenceSummary()
        return didMutate
    }

    func connectionStateForTesting() -> CollaborationConnectionState {
        connectionState
    }

    func activeRoomIDsForTesting() -> Set<String> {
        activeRoomIDs
    }

    func taskRecordsForTesting(roomID: String) -> [CollaborativeTaskRecord] {
        roomStatesByID[normalizeRoomID(roomID)]?.taskSet.resolvedEntries ?? []
    }

    func lastSequenceForTesting(roomID: String) -> Int64 {
        roomStatesByID[normalizeRoomID(roomID)]?.lastSequence ?? 0
    }

    func handleIncomingEnvelopeForTesting(_ envelope: CollaborationRealtimeEnvelope) async {
        await ingestIncomingEnvelope(envelope)
    }

    func triggerForegroundReconnectForTesting() async {
        await handleWillEnterForeground()
    }

    nonisolated static func reconnectDelaySeconds(forAttempt attempt: Int, jitter: Double) -> TimeInterval {
        let normalizedAttempt = max(1, attempt)
        let cappedBase = min(pow(2.0, Double(normalizedAttempt - 1)), 60.0)
        let boundedJitter = min(max(jitter, 0.5), 1.0)
        return min(cappedBase * boundedJitter, 60.0)
    }

    private static func decodePersistedRooms(from data: Data?) -> [String: PersistedRoomState] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: PersistedRoomState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func emptyRoomState() -> RoomRuntimeState {
        RoomRuntimeState(
            taskSet: CollaborativeTaskLWWSet(),
            lastSequence: 0,
            completionOverlay: [:],
            bufferedEnvelopes: [:],
            seenOperationIDs: [],
            presenceByUserID: [:]
        )
    }

    private func ensureRoomStateExists(for roomID: String) {
        if roomStatesByID[roomID] == nil {
            roomStatesByID[roomID] = Self.emptyRoomState()
        }
    }

    private func persistRoomMembership() {
        defaults.set(activeRoomIDs.sorted(), forKey: activeRoomsKey)
    }

    private func persistRoomsState() {
        let persisted = roomStatesByID.mapValues { roomState in
            PersistedRoomState(
                taskSet: roomState.taskSet,
                lastSequence: roomState.lastSequence
            )
        }
        guard let encoded = try? JSONEncoder().encode(persisted) else { return }
        defaults.set(encoded, forKey: roomStateKey)
    }

    private func normalizeRoomID(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func connectRealtimeChannelIfNeeded(forceReconnect: Bool) async {
        guard realtimeEnabled else {
            connectionState = .failed(reason: "collaboration_realtime_disabled")
            return
        }

        if !forceReconnect {
            switch connectionState {
            case .connecting, .connected, .reconnecting:
                return
            case .disconnected, .disconnecting, .failed:
                break
            }
        } else {
            await disconnectTransport(markFailed: false)
        }

        guard let websocketURL else {
            connectionState = .failed(reason: "missing_collaboration_websocket_url")
            return
        }

        if activeRoomIDs.isEmpty {
            activeRoomIDs.insert(journeyID)
            persistRoomMembership()
        }

        connectionState = reconnectAttempt == 0 ? .connecting : .reconnecting(attempt: reconnectAttempt)
        do {
            try await transport.connect(url: websocketURL)
            preReceiveBuffer = []
            for roomID in activeRoomIDs.sorted() {
                try await joinRoomOnTransport(roomID)
            }
            startReceiveLoop()
            connectedAt = nowProvider()
            connectionState = .connected
            if localPresenceIsActive {
                startPresenceHeartbeatIfNeeded()
                await sendCurrentPresence()
            }
        } catch {
            CrashReporter.record(error: error, context: "collaboration_connect")
            await handleUnexpectedDisconnect(reason: "connect_failed")
        }
    }

    private func joinRoomOnTransport(_ roomID: String) async throws {
        ensureRoomStateExists(for: roomID)
        let roomState = roomStatesByID[roomID] ?? Self.emptyRoomState()
        let requestID = UUID().uuidString
        try await transport.send(
            CollaborationRealtimeEnvelope(
                type: "join",
                roomID: roomID,
                requestID: requestID,
                operationID: UUID().uuidString,
                sequenceNumber: roomState.lastSequence,
                historyEvicted: false,
                task: nil,
                tasks: nil,
                presence: currentPresenceSignal(),
                snapshot: nil
            )
        )

        let deadline = nowProvider().addingTimeInterval(joinTimeoutSeconds)
        while nowProvider() < deadline {
            let envelope = try await transport.receive()
            if envelope.type == "snapshot",
               envelope.roomID == roomID,
               envelope.requestID == requestID {
                applySnapshotEnvelope(envelope, roomID: roomID)
                return
            }
            preReceiveBuffer.append(envelope)
        }

        throw CollaborationRealtimeTransportError.joinTimeout
    }

    private func sendJoinRequest(for roomID: String) async throws {
        ensureRoomStateExists(for: roomID)
        let roomState = roomStatesByID[roomID] ?? Self.emptyRoomState()
        try await transport.send(
            CollaborationRealtimeEnvelope(
                type: "join",
                roomID: roomID,
                requestID: UUID().uuidString,
                operationID: UUID().uuidString,
                sequenceNumber: roomState.lastSequence,
                historyEvicted: false,
                task: nil,
                tasks: nil,
                presence: currentPresenceSignal(),
                snapshot: nil
            )
        )
    }

    private func startReceiveLoop() {
        receiveLoopTask?.cancel()
        receiveLoopTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !self.preReceiveBuffer.isEmpty {
                let buffered = self.preReceiveBuffer.removeFirst()
                await self.ingestIncomingEnvelope(buffered)
            }

            while !Task.isCancelled {
                do {
                    let envelope = try await self.transport.receive()
                    await self.ingestIncomingEnvelope(envelope)
                } catch is CancellationError {
                    return
                } catch {
                    CrashReporter.record(error: error, context: "collaboration_receive_loop")
                    await self.handleUnexpectedDisconnect(reason: "receive_failed")
                    return
                }
            }
        }
    }

    private func sendTaskUpdate(_ task: CollaborativeTaskRecord, roomID: String) async {
        guard connectionState == .connected else { return }
        let normalizedRoomID = normalizeRoomID(roomID)
        guard !normalizedRoomID.isEmpty else { return }
        let sequenceNumber = (roomStatesByID[normalizedRoomID]?.lastSequence ?? 0) + 1
        let envelope = CollaborationRealtimeEnvelope(
            type: "task_update",
            roomID: normalizedRoomID,
            requestID: nil,
            operationID: UUID().uuidString,
            sequenceNumber: sequenceNumber,
            historyEvicted: false,
            task: task,
            tasks: nil,
            presence: nil,
            snapshot: nil
        )
        do {
            try await transport.send(envelope)
        } catch {
            CrashReporter.record(error: error, context: "collaboration_send_task")
            await handleUnexpectedDisconnect(reason: "task_send_failed")
        }
    }

    private func sendCurrentPresence() async {
        guard connectionState == .connected else { return }
        let presence = currentPresenceSignal()
        for roomID in activeRoomIDs.sorted() {
            let sequenceNumber = (roomStatesByID[roomID]?.lastSequence ?? 0) + 1
            let envelope = CollaborationRealtimeEnvelope(
                type: "presence",
                roomID: roomID,
                requestID: nil,
                operationID: UUID().uuidString,
                sequenceNumber: sequenceNumber,
                historyEvicted: false,
                task: nil,
                tasks: nil,
                presence: presence,
                snapshot: nil
            )
            do {
                try await transport.send(envelope)
            } catch {
                CrashReporter.record(error: error, context: "collaboration_send_presence")
                await handleUnexpectedDisconnect(reason: "presence_send_failed")
                return
            }
        }
    }

    private func currentPresenceSignal() -> PresenceSignal {
        PresenceSignal(
            userID: actorID,
            displayName: localDisplayName,
            isActive: localPresenceIsActive,
            viewingTaskID: localViewingTaskID,
            sentAtMillis: epochMillis(nowProvider())
        )
    }

    private func ingestIncomingEnvelope(_ envelope: CollaborationRealtimeEnvelope) async {
        let roomID = normalizeRoomID(envelope.roomID)
        guard !roomID.isEmpty, activeRoomIDs.contains(roomID) else { return }
        ensureRoomStateExists(for: roomID)

        switch envelope.type {
        case "snapshot":
            applySnapshotEnvelope(envelope, roomID: roomID)
        case "peer_disconnected":
            if let presence = envelope.presence, presence.userID != actorID {
                schedulePresenceGraceRemoval(for: presence.userID, roomID: roomID)
            }
        case "task_update", "presence":
            applyOperationalEnvelope(envelope, roomID: roomID)
        default:
            break
        }
    }

    private func applySnapshotEnvelope(_ envelope: CollaborationRealtimeEnvelope, roomID: String) {
        let snapshot = envelope.snapshot ?? CollaborationRoomSnapshot(
            roomID: roomID,
            sequenceNumber: envelope.sequenceNumber,
            tasks: envelope.tasks ?? envelope.task.map { [$0] } ?? [],
            presence: envelope.presence.map { [$0] } ?? [],
            historyEvicted: envelope.historyEvicted
        )

        let previousEntries = Dictionary(
            uniqueKeysWithValues: (roomStatesByID[roomID]?.taskSet.resolvedEntries ?? []).map { ($0.id, $0) }
        )
        var nextTaskSet = CollaborativeTaskLWWSet()
        for task in snapshot.tasks {
            nextTaskSet.upsert(task)
        }

        var roomState = roomStatesByID[roomID] ?? Self.emptyRoomState()
        roomState.taskSet = nextTaskSet
        roomState.lastSequence = snapshot.sequenceNumber
        if snapshot.historyEvicted {
            roomState.bufferedEnvelopes = [:]
        } else {
            roomState.bufferedEnvelopes = roomState.bufferedEnvelopes.filter { $0.key > roomState.lastSequence }
        }
        roomState.presenceByUserID = Dictionary(uniqueKeysWithValues: snapshot.presence.map { ($0.userID, $0) })
        roomStatesByID[roomID] = roomState
        _ = updateCompletionOverlay(roomID: roomID, beforeEntries: previousEntries, roomState: &roomState)
        roomStatesByID[roomID] = roomState
        pendingResyncRoomIDs.remove(roomID)
        persistRoomsState()
        refreshPresenceSummary()
        drainBufferedEnvelopes(for: roomID)
    }

    private func applyOperationalEnvelope(_ envelope: CollaborationRealtimeEnvelope, roomID: String) {
        var roomState = roomStatesByID[roomID] ?? Self.emptyRoomState()
        if let operationID = envelope.operationID,
           roomState.seenOperationIDs.contains(operationID) {
            return
        }

        let nextExpected = roomState.lastSequence + 1
        if envelope.sequenceNumber <= roomState.lastSequence {
            return
        }

        if envelope.sequenceNumber > nextExpected {
            roomState.bufferedEnvelopes[envelope.sequenceNumber] = envelope
            roomStatesByID[roomID] = roomState
            persistRoomsState()
            requestResyncIfNeeded(for: roomID)
            return
        }

        applyOrderedEnvelope(envelope, roomID: roomID, roomState: &roomState)
        roomStatesByID[roomID] = roomState
        persistRoomsState()
        drainBufferedEnvelopes(for: roomID)
        refreshPresenceSummary()
    }

    private func applyOrderedEnvelope(
        _ envelope: CollaborationRealtimeEnvelope,
        roomID: String,
        roomState: inout RoomRuntimeState
    ) {
        let beforeEntries = Dictionary(uniqueKeysWithValues: roomState.taskSet.resolvedEntries.map { ($0.id, $0) })

        switch envelope.type {
        case "task_update":
            if let task = envelope.task {
                roomState.taskSet.upsert(task)
            }
            for task in envelope.tasks ?? [] {
                roomState.taskSet.upsert(task)
            }
        case "presence":
            if let presence = envelope.presence, presence.userID != actorID {
                cancelPresenceGraceRemoval(for: presence.userID, roomID: roomID)
                roomState.presenceByUserID[presence.userID] = presence
            }
        default:
            break
        }

        roomState.lastSequence = envelope.sequenceNumber
        if let operationID = envelope.operationID {
            roomState.seenOperationIDs.append(operationID)
            if roomState.seenOperationIDs.count > seenOperationLimit {
                roomState.seenOperationIDs.removeFirst(roomState.seenOperationIDs.count - seenOperationLimit)
            }
        }

        _ = updateCompletionOverlay(roomID: roomID, beforeEntries: beforeEntries, roomState: &roomState)
    }

    private func drainBufferedEnvelopes(for roomID: String) {
        guard var roomState = roomStatesByID[roomID] else { return }
        while let envelope = roomState.bufferedEnvelopes[roomState.lastSequence + 1] {
            roomState.bufferedEnvelopes.removeValue(forKey: roomState.lastSequence + 1)
            applyOrderedEnvelope(envelope, roomID: roomID, roomState: &roomState)
        }
        roomStatesByID[roomID] = roomState
        persistRoomsState()
    }

    private func requestResyncIfNeeded(for roomID: String) {
        guard !pendingResyncRoomIDs.contains(roomID) else { return }
        guard connectionState == .connected else { return }
        pendingResyncRoomIDs.insert(roomID)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let sequenceNumber = self.roomStatesByID[roomID]?.lastSequence ?? 0
            let envelope = CollaborationRealtimeEnvelope(
                type: "resync_request",
                roomID: roomID,
                requestID: UUID().uuidString,
                operationID: UUID().uuidString,
                sequenceNumber: sequenceNumber,
                historyEvicted: false,
                task: nil,
                tasks: nil,
                presence: self.currentPresenceSignal(),
                snapshot: nil
            )
            do {
                try await self.transport.send(envelope)
            } catch {
                CrashReporter.record(error: error, context: "collaboration_resync_request")
                await self.handleUnexpectedDisconnect(reason: "resync_failed")
            }
        }
    }

    private func updateCompletionOverlay(
        roomID: String,
        beforeEntries: [String: CollaborativeTaskRecord],
        roomState: inout RoomRuntimeState
    ) -> Bool {
        var didMutate = false
        for entry in roomState.taskSet.resolvedEntries where entry.status == .completed {
            let previousStatus = beforeEntries[entry.id]?.status
            if previousStatus != .completed {
                let completedDate = entry.completedAtMillis.map(dateFromEpochMillis(_:)) ?? nowProvider()
                roomState.completionOverlay[entry.id] = completedDate
                didMutate = true

                if entry.isTier1Urgent, roomID == journeyID {
                    Task {
                        await NotificationManager.shared.scheduleCollaborativeUrgentAlert(
                            taskTitle: entry.title,
                            taskID: entry.id
                        )
                    }
                }
            }
        }
        return didMutate
    }

    private func refreshPresenceSummary() {
        guard let roomState = roomStatesByID[journeyID] else {
            collaboratorDisplayName = "Roommate"
            collaboratorViewingTaskID = nil
            collaboratorIsActive = false
            collaboratorLastHeartbeatAt = nil
            return
        }

        let candidate = roomState.presenceByUserID.values
            .filter { $0.userID != actorID && $0.isActive }
            .sorted { lhs, rhs in
                if lhs.sentAtMillis != rhs.sentAtMillis {
                    return lhs.sentAtMillis > rhs.sentAtMillis
                }
                return lhs.userID < rhs.userID
            }
            .first

        guard let candidate else {
            collaboratorDisplayName = "Roommate"
            collaboratorViewingTaskID = nil
            collaboratorIsActive = false
            collaboratorLastHeartbeatAt = nil
            return
        }

        collaboratorDisplayName = candidate.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Roommate"
            : candidate.displayName
        collaboratorViewingTaskID = candidate.viewingTaskID
        collaboratorIsActive = candidate.isActive
        collaboratorLastHeartbeatAt = dateFromEpochMillis(candidate.sentAtMillis)
    }

    private func startPresenceHeartbeatIfNeeded() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled else { return }
                await self.sendCurrentPresence()
            }
        }
    }

    private func stopPresenceHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func schedulePresenceGraceRemoval(for userID: String, roomID: String) {
        let key = presenceGraceKey(userID: userID, roomID: roomID)
        presenceGraceTasks[key]?.cancel()
        presenceGraceTasks[key] = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sleepProvider(self.presenceGracePeriodSeconds)
            guard !Task.isCancelled else { return }
            var roomState = self.roomStatesByID[roomID] ?? Self.emptyRoomState()
            roomState.presenceByUserID.removeValue(forKey: userID)
            self.roomStatesByID[roomID] = roomState
            self.persistRoomsState()
            self.refreshPresenceSummary()
            self.presenceGraceTasks.removeValue(forKey: key)
        }
    }

    private func cancelPresenceGraceRemoval(for userID: String, roomID: String) {
        let key = presenceGraceKey(userID: userID, roomID: roomID)
        presenceGraceTasks[key]?.cancel()
        presenceGraceTasks.removeValue(forKey: key)
    }

    private func cancelPresenceGraceTasks(for roomID: String) {
        for key in presenceGraceTasks.keys where key.hasSuffix("|\(roomID)") {
            presenceGraceTasks[key]?.cancel()
            presenceGraceTasks.removeValue(forKey: key)
        }
    }

    private func presenceGraceKey(userID: String, roomID: String) -> String {
        "\(userID)|\(roomID)"
    }

    private func nextLamportTimestamp() -> LamportTimestamp {
        lamportCounter += 1
        defaults.set(lamportCounter, forKey: lamportCounterKey)
        return LamportTimestamp(counter: lamportCounter, actorID: actorID)
    }

    private func decodeTaskRecords(from rawPayload: Any?) -> [CollaborativeTaskRecord] {
        if let records = rawPayload as? [CollaborativeTaskRecord] {
            return records
        }

        if let dictionaries = rawPayload as? [[String: Any]] {
            guard let data = try? JSONSerialization.data(withJSONObject: dictionaries) else { return [] }
            return (try? JSONDecoder().decode([CollaborativeTaskRecord].self, from: data)) ?? []
        }

        if let jsonString = rawPayload as? String,
           let data = jsonString.data(using: .utf8) {
            return (try? JSONDecoder().decode([CollaborativeTaskRecord].self, from: data)) ?? []
        }

        return []
    }

    private func handleWillEnterForeground() async {
        guard realtimeEnabled else { return }
        switch connectionState {
        case .disconnected, .failed:
            await connectRealtimeChannelIfNeeded(forceReconnect: true)
        case .connecting, .connected, .disconnecting, .reconnecting:
            break
        }
    }

    private func handleUnexpectedDisconnect(reason: String) async {
        if let connectedAt, nowProvider().timeIntervalSince(connectedAt) > stableConnectionResetSeconds {
            reconnectAttempt = 0
        }
        connectedAt = nil
        await disconnectTransport(markFailed: false)
        for roomID in activeRoomIDs {
            if let roomState = roomStatesByID[roomID] {
                for userID in roomState.presenceByUserID.keys where userID != actorID {
                    schedulePresenceGraceRemoval(for: userID, roomID: roomID)
                }
            }
        }

        guard reconnectAttempt < maximumReconnectAttempts else {
            connectionState = .failed(reason: reason)
            return
        }

        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)
        let delay = Self.reconnectDelaySeconds(
            forAttempt: reconnectAttempt,
            jitter: jitterProvider()
        )

        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.sleepProvider(delay)
            guard !Task.isCancelled else { return }
            await self.connectRealtimeChannelIfNeeded(forceReconnect: true)
        }
    }

    private func disconnectTransport(markFailed: Bool) async {
        connectionState = .disconnecting
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        await transport.disconnect()
        connectionState = markFailed ? .failed(reason: "disconnected") : .disconnected
    }

    private func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private func dateFromEpochMillis(_ millis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }
}
