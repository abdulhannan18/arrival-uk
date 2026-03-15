import Foundation
import Observation
import SwiftUI

@available(iOS 17.0, *)
@MainActor
@Observable
final class CollaborationSyncEngine {
    static let shared = CollaborationSyncEngine()

    struct PresenceSignal: Codable, Hashable {
        var userID: String
        var displayName: String
        var isActive: Bool
        var viewingTaskID: String?
        var sentAtMillis: Int64
    }

    private struct RealtimeEnvelope: Codable {
        var type: String
        var journeyID: String
        var task: CollaborativeTaskRecord?
        var tasks: [CollaborativeTaskRecord]?
        var presence: PresenceSignal?
    }

    private let actorIDKey = StorageKey.collaborationActorID.rawValue
    private let lamportCounterKey = StorageKey.collaborationLamportCounter.rawValue
    private let taskSetKey = StorageKey.collaborationTaskSet.rawValue
    private let journeyIDKey = StorageKey.collaborationJourneyID.rawValue
    private let heartbeatKey = StorageKey.collaborationPresenceHeartbeat.rawValue

    private var actorID: String
    private var lamportCounter: Int64
    private var taskSet: CollaborativeTaskLWWSet
    private var completionOverlay: [String: Date] = [:]
    private var websocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var hasConfigured = false
    private var localViewingTaskID: String?
    private var localDisplayName: String

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

    private init() {
        let defaults = UserDefaults.standard

        let resolvedActorID: String
        if let persistedActorID = defaults.string(forKey: StorageKey.collaborationActorID.rawValue),
           !persistedActorID.isEmpty {
            resolvedActorID = persistedActorID
        } else {
            resolvedActorID = UUID().uuidString
            defaults.set(resolvedActorID, forKey: StorageKey.collaborationActorID.rawValue)
        }

        let resolvedLamportCounter = defaults.object(forKey: StorageKey.collaborationLamportCounter.rawValue) as? Int64 ?? 0
        let resolvedLocalDisplayName = StudentProfileStore.shared.preferredFirstName ?? "You"

        let resolvedTaskSet: CollaborativeTaskLWWSet
        if let persistedTaskSetData = defaults.data(forKey: StorageKey.collaborationTaskSet.rawValue),
           let decodedTaskSet = try? JSONDecoder().decode(CollaborativeTaskLWWSet.self, from: persistedTaskSetData) {
            resolvedTaskSet = decodedTaskSet
        } else {
            resolvedTaskSet = CollaborativeTaskLWWSet()
        }

        let persistedJourneyID = defaults.string(forKey: StorageKey.collaborationJourneyID.rawValue)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedJourneyID = (persistedJourneyID?.isEmpty == false) ? persistedJourneyID! : "default-journey"

        actorID = resolvedActorID
        lamportCounter = resolvedLamportCounter
        localDisplayName = resolvedLocalDisplayName
        taskSet = resolvedTaskSet
        journeyID = resolvedJourneyID
    }

    func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true
        connectRealtimeChannelIfNeeded()
    }

    func setJourneyID(_ journeyID: String) {
        let normalized = journeyID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        self.journeyID = normalized
        UserDefaults.standard.set(normalized, forKey: journeyIDKey)
    }

    func markLocalPresence(isActive: Bool) {
        if !isActive {
            localViewingTaskID = nil
        }

        let presence = PresenceSignal(
            userID: actorID,
            displayName: localDisplayName,
            isActive: isActive,
            viewingTaskID: localViewingTaskID,
            sentAtMillis: epochMillis(Date())
        )
        UserDefaults.standard.set(Date(), forKey: heartbeatKey)
        sendPresence(presence)

        if isActive {
            startPresenceHeartbeatIfNeeded()
            connectRealtimeChannelIfNeeded()
        } else {
            stopPresenceHeartbeat()
        }
    }

    func publishViewing(taskID: String?) {
        localViewingTaskID = taskID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let presence = PresenceSignal(
            userID: actorID,
            displayName: localDisplayName,
            isActive: true,
            viewingTaskID: localViewingTaskID,
            sentAtMillis: epochMillis(Date())
        )
        sendPresence(presence)
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
        taskSet.upsert(record)
        completionOverlay[trimmedID] = completedAt
        persistState()
        sendTaskUpdate(record)
    }

    func consumeCompletionOverlay() -> [String: Date] {
        let snapshot = completionOverlay
        completionOverlay = [:]
        return snapshot
    }

    func handleSilentPushPayload(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard let rawType = userInfo["type"] as? String else { return false }
        let normalizedType = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedType == "collaboration_sync" || normalizedType == "collab_sync" else {
            return false
        }

        let records = decodeTaskRecords(from: userInfo["tasks"])
        let didMerge = mergeRemote(records: records)
        if didMerge {
            NotificationCenter.default.post(name: .didReceiveSilentCollaborationSync, object: nil, userInfo: userInfo)
        }
        return didMerge
    }

    func mergeRemote(records: [CollaborativeTaskRecord]) -> Bool {
        guard !records.isEmpty else { return false }

        let beforeMap = Dictionary(uniqueKeysWithValues: taskSet.resolvedEntries.map { ($0.id, $0) })
        var remoteSet = CollaborativeTaskLWWSet()
        for record in records {
            remoteSet.upsert(record)
        }
        taskSet.merge(with: remoteSet)
        let afterEntries = taskSet.resolvedEntries

        var didMutate = false
        for entry in afterEntries where entry.status == .completed {
            let beforeStatus = beforeMap[entry.id]?.status
            if beforeStatus != .completed {
                let completedDate = entry.completedAtMillis.map(dateFromEpochMillis(_:)) ?? .now
                completionOverlay[entry.id] = completedDate
                didMutate = true

                if entry.isTier1Urgent {
                    Task {
                        await NotificationManager.shared.scheduleCollaborativeUrgentAlert(
                            taskTitle: entry.title,
                            taskID: entry.id
                        )
                    }
                }
            }
        }

        if didMutate {
            persistState()
        }
        return didMutate
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

    private func nextLamportTimestamp() -> LamportTimestamp {
        lamportCounter += 1
        UserDefaults.standard.set(lamportCounter, forKey: lamportCounterKey)
        return LamportTimestamp(counter: lamportCounter, actorID: actorID)
    }

    private func persistState() {
        guard let encoded = try? JSONEncoder().encode(taskSet) else { return }
        UserDefaults.standard.set(encoded, forKey: taskSetKey)
    }

    private func connectRealtimeChannelIfNeeded() {
        guard websocketTask == nil else { return }
        guard let websocketURL = AppConfig.collaborationWebSocketURL else { return }

        let task = URLSession.shared.webSocketTask(with: websocketURL)
        websocketTask = task
        task.resume()
        startReceiveLoop()
        sendHello()
    }

    private func sendHello() {
        let envelope = RealtimeEnvelope(
            type: "hello",
            journeyID: journeyID,
            task: nil,
            tasks: nil,
            presence: PresenceSignal(
                userID: actorID,
                displayName: localDisplayName,
                isActive: true,
                viewingTaskID: localViewingTaskID,
                sentAtMillis: epochMillis(Date())
            )
        )
        sendEnvelope(envelope)
    }

    private func sendTaskUpdate(_ task: CollaborativeTaskRecord) {
        let envelope = RealtimeEnvelope(
            type: "task_update",
            journeyID: journeyID,
            task: task,
            tasks: nil,
            presence: nil
        )
        sendEnvelope(envelope)
    }

    private func sendPresence(_ presence: PresenceSignal) {
        let envelope = RealtimeEnvelope(
            type: "presence",
            journeyID: journeyID,
            task: nil,
            tasks: nil,
            presence: presence
        )
        sendEnvelope(envelope)
    }

    private func sendEnvelope(_ envelope: RealtimeEnvelope) {
        guard let websocketTask else { return }
        guard let data = try? JSONEncoder().encode(envelope),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        websocketTask.send(.string(text)) { error in
            guard let error else { return }
            CrashReporter.record(error: error, context: "collaboration_ws_send")
        }
    }

    private func startReceiveLoop() {
        receiveLoopTask?.cancel()
        receiveLoopTask = Task {
            while !Task.isCancelled {
                guard let websocketTask else { return }
                do {
                    let message = try await websocketTask.receive()
                    switch message {
                    case .string(let text):
                        handleRealtimeMessageText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            handleRealtimeMessageText(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    CrashReporter.record(error: error, context: "collaboration_ws_receive")
                    self.websocketTask = nil
                    return
                }
            }
        }
    }

    private func handleRealtimeMessageText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(RealtimeEnvelope.self, from: data) else {
            return
        }

        switch envelope.type {
        case "task_update":
            if let task = envelope.task {
                _ = mergeRemote(records: [task])
            } else if let tasks = envelope.tasks {
                _ = mergeRemote(records: tasks)
            }
        case "presence":
            if let presence = envelope.presence, presence.userID != actorID {
                applyPresence(presence)
            }
        default:
            break
        }
    }

    private func applyPresence(_ presence: PresenceSignal) {
        collaboratorDisplayName = presence.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Roommate"
            : presence.displayName
        collaboratorIsActive = presence.isActive
        collaboratorViewingTaskID = presence.viewingTaskID
        collaboratorLastHeartbeatAt = dateFromEpochMillis(presence.sentAtMillis)
    }

    private func startPresenceHeartbeatIfNeeded() {
        guard heartbeatTask == nil else { return }

        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled else { return }
                let signal = PresenceSignal(
                    userID: actorID,
                    displayName: localDisplayName,
                    isActive: true,
                    viewingTaskID: localViewingTaskID,
                    sentAtMillis: epochMillis(Date())
                )
                sendPresence(signal)
            }
        }
    }

    private func stopPresenceHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private func dateFromEpochMillis(_ millis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }
}
