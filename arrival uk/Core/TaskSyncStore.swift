import Foundation
import Network
import Observation
import SwiftData
import SwiftUI
import UIKit

enum TaskSyncStatus: String, Codable {
    case synced
    case pending
}

@Model
final class TaskEntity {
    @Attribute(.unique) var id: String
    var title: String
    var categoryID: String
    var isCompleted: Bool
    var phase: Int
    var lastModified: Date
    var syncStatusRaw: String

    init(
        id: String,
        title: String,
        categoryID: String,
        isCompleted: Bool,
        phase: Int,
        lastModified: Date,
        syncStatus: TaskSyncStatus
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.isCompleted = isCompleted
        self.phase = phase
        self.lastModified = lastModified
        self.syncStatusRaw = syncStatus.rawValue
    }

    var syncStatus: TaskSyncStatus {
        get { TaskSyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
}

@available(iOS 17.0, *)
@MainActor
@Observable
final class TaskSyncStore {
    static let shared = TaskSyncStore()

    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.arrivaluk.tasksync.path-monitor")
    private let minimumSyncInterval: TimeInterval = 8
    private var lastSyncAttemptAt: Date?
    private var backgroundSyncTaskID: UIBackgroundTaskIdentifier = .invalid
    private var hasConfigured = false
    private var isNetworkReachable = true
    private var isSyncInFlight = false
    private let container: ModelContainer?

    var pendingUpdateCount = 0

    private init() {
        do {
            container = try ModelContainer(for: TaskEntity.self)
        } catch {
            container = nil
            CrashReporter.record(error: error, context: "task_sync_container_init")
        }
        pendingUpdateCount = localPendingCount()
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

        Task {
            await flushPendingUpdatesIfNeeded(reason: "startup", force: true)
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active {
            Task {
                await flushPendingUpdatesIfNeeded(reason: "scene_active", force: true)
            }
            return
        }

        if phase == .background, pendingUpdateCount > 0, isNetworkReachable {
            beginBackgroundSyncWindowIfNeeded()
            Task {
                await flushPendingUpdatesIfNeeded(reason: "scene_background", force: true)
                endBackgroundSyncWindowIfNeeded()
            }
        }
    }

    func mirrorQueues(survivalQueue: [AppTask], maintenanceTasks: [AppTask]) {
        guard let context = makeContext() else { return }

        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            var entitiesByID = Dictionary(uniqueKeysWithValues: allEntities.map { ($0.id, $0) })
            let now = Date()

            for task in survivalQueue {
                upsertQueuedTask(
                    task: task,
                    phase: 1,
                    now: now,
                    context: context,
                    entitiesByID: &entitiesByID
                )
            }

            for task in maintenanceTasks {
                upsertQueuedTask(
                    task: task,
                    phase: 2,
                    now: now,
                    context: context,
                    entitiesByID: &entitiesByID
                )
            }

            try context.save()
        } catch {
            CrashReporter.record(error: error, context: "task_sync_mirror_queues")
        }

        pendingUpdateCount = localPendingCount()
    }

    func recordCompletion(
        taskID: String,
        title: String,
        categoryID: String,
        phase: Int,
        completedAt: Date = .now
    ) {
        guard let context = makeContext() else { return }

        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            if let existing = allEntities.first(where: { $0.id == taskID }) {
                existing.title = title
                existing.categoryID = categoryID
                existing.isCompleted = true
                existing.phase = phase
                existing.lastModified = completedAt
                existing.syncStatus = .pending
            } else {
                let entity = TaskEntity(
                    id: taskID,
                    title: title,
                    categoryID: categoryID,
                    isCompleted: true,
                    phase: phase,
                    lastModified: completedAt,
                    syncStatus: .pending
                )
                context.insert(entity)
            }
            try context.save()
        } catch {
            CrashReporter.record(error: error, context: "task_sync_record_completion")
        }

        pendingUpdateCount = localPendingCount()
        Task {
            await flushPendingUpdatesIfNeeded(reason: "task_completed", force: false)
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
        guard !isSyncInFlight else { return }
        guard let pendingUpdates = pendingSnapshots(), !pendingUpdates.isEmpty else {
            pendingUpdateCount = 0
            return
        }

        if !force, let lastSyncAttemptAt, Date().timeIntervalSince(lastSyncAttemptAt) < minimumSyncInterval {
            return
        }

        lastSyncAttemptAt = Date()
        isSyncInFlight = true
        defer { isSyncInFlight = false }

        let requestBody = TaskSyncRequestPayload(
            updates: pendingUpdates.map(TaskSyncUpdatePayload.init(snapshot:)),
            sentAtMillis: epochMillis(Date())
        )

        let body: Data
        do {
            let encoder = JSONEncoder()
            body = try encoder.encode(requestBody)
        } catch {
            CrashReporter.record(error: error, context: "task_sync_encode_payload")
            return
        }

        do {
            let response: TaskSyncResponsePayload = try await SecureHTTPClient.shared.request(
                endpoint: syncEndpoint,
                method: .post,
                body: body
            )
            applyServerAcknowledgement(
                sentUpdateIDs: Set(pendingUpdates.map(\.id)),
                serverUpdates: response.updates
            )
        } catch {
            CrashReporter.record(error: error, context: "task_sync_flush_\(reason)")
        }

        pendingUpdateCount = localPendingCount()
    }

    private var syncEndpoint: String {
        AppConfig.apiBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("tasks")
            .appendingPathComponent("sync")
            .absoluteString
    }

    private func upsertQueuedTask(
        task: AppTask,
        phase: Int,
        now: Date,
        context: ModelContext,
        entitiesByID: inout [String: TaskEntity]
    ) {
        if let existing = entitiesByID[task.id] {
            existing.title = task.title
            existing.categoryID = task.categoryID
            existing.phase = phase

            if existing.isCompleted {
                existing.isCompleted = false
                existing.lastModified = now
                existing.syncStatus = .pending
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
            syncStatus: .synced
        )
        context.insert(entity)
        entitiesByID[task.id] = entity
    }

    private func pendingSnapshots() -> [PendingTaskSnapshot]? {
        guard let context = makeContext() else { return nil }

        do {
            let allEntities = try context.fetch(
                FetchDescriptor<TaskEntity>(sortBy: [SortDescriptor(\TaskEntity.lastModified)])
            )
            let pending = allEntities
                .filter { $0.syncStatus == .pending }
                .map(PendingTaskSnapshot.init(entity:))
            return pending
        } catch {
            CrashReporter.record(error: error, context: "task_sync_fetch_pending")
            return nil
        }
    }

    private func applyServerAcknowledgement(
        sentUpdateIDs: Set<String>,
        serverUpdates: [RemoteTaskSyncUpdate]
    ) {
        guard let context = makeContext() else { return }

        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            var entitiesByID = Dictionary(uniqueKeysWithValues: allEntities.map { ($0.id, $0) })

            for updateID in sentUpdateIDs {
                guard let entity = entitiesByID[updateID] else { continue }
                entity.syncStatus = .synced
            }

            for update in serverUpdates {
                let trimmedID = update.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedID.isEmpty else { continue }

                let remoteDate = Date(timeIntervalSince1970: TimeInterval(update.lastModifiedMillis) / 1000)
                if let localEntity = entitiesByID[trimmedID] {
                    if remoteDate > localEntity.lastModified {
                        localEntity.title = update.title ?? localEntity.title
                        localEntity.categoryID = update.categoryID ?? localEntity.categoryID
                        localEntity.isCompleted = update.isCompleted
                        localEntity.phase = update.phase
                        localEntity.lastModified = remoteDate
                        localEntity.syncStatus = .synced
                    } else if remoteDate < localEntity.lastModified {
                        localEntity.syncStatus = .pending
                    } else {
                        localEntity.syncStatus = .synced
                    }
                    continue
                }

                let inserted = TaskEntity(
                    id: trimmedID,
                    title: update.title ?? "Task",
                    categoryID: update.categoryID ?? "",
                    isCompleted: update.isCompleted,
                    phase: update.phase,
                    lastModified: remoteDate,
                    syncStatus: .synced
                )
                context.insert(inserted)
                entitiesByID[trimmedID] = inserted
            }

            try context.save()
        } catch {
            CrashReporter.record(error: error, context: "task_sync_apply_server_ack")
        }
    }

    private func localPendingCount() -> Int {
        guard let context = makeContext() else { return 0 }
        do {
            let allEntities = try context.fetch(FetchDescriptor<TaskEntity>())
            return allEntities.reduce(0) { partial, entity in
                partial + (entity.syncStatus == .pending ? 1 : 0)
            }
        } catch {
            CrashReporter.record(error: error, context: "task_sync_pending_count")
            return 0
        }
    }

    private func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    private func beginBackgroundSyncWindowIfNeeded() {
        guard backgroundSyncTaskID == .invalid else { return }

        backgroundSyncTaskID = UIApplication.shared.beginBackgroundTask(withName: "arrivaluk.task-sync") { [weak self] in
            guard let self else { return }
            if self.backgroundSyncTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundSyncTaskID)
                self.backgroundSyncTaskID = .invalid
            }
        }
    }

    private func endBackgroundSyncWindowIfNeeded() {
        guard backgroundSyncTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundSyncTaskID)
        backgroundSyncTaskID = .invalid
    }

    private func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

private struct PendingTaskSnapshot {
    let id: String
    let title: String
    let categoryID: String
    let isCompleted: Bool
    let phase: Int
    let lastModified: Date
    let syncStatusRaw: String

    init(entity: TaskEntity) {
        self.id = entity.id
        self.title = entity.title
        self.categoryID = entity.categoryID
        self.isCompleted = entity.isCompleted
        self.phase = entity.phase
        self.lastModified = entity.lastModified
        self.syncStatusRaw = entity.syncStatusRaw
    }
}

private struct TaskSyncRequestPayload: Encodable {
    let updates: [TaskSyncUpdatePayload]
    let sentAtMillis: Int64
}

private struct TaskSyncUpdatePayload: Encodable {
    let id: String
    let title: String
    let categoryID: String
    let isCompleted: Bool
    let phase: Int
    let lastModifiedMillis: Int64
    let syncStatus: String

    init(snapshot: PendingTaskSnapshot) {
        self.id = snapshot.id
        self.title = snapshot.title
        self.categoryID = snapshot.categoryID
        self.isCompleted = snapshot.isCompleted
        self.phase = snapshot.phase
        self.lastModifiedMillis = Int64((snapshot.lastModified.timeIntervalSince1970 * 1000).rounded())
        self.syncStatus = snapshot.syncStatusRaw
    }
}

private struct TaskSyncResponsePayload: Decodable {
    let updates: [RemoteTaskSyncUpdate]

    enum CodingKeys: String, CodingKey {
        case updates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updates = (try? container.decode([RemoteTaskSyncUpdate].self, forKey: .updates)) ?? []
    }
}

private struct RemoteTaskSyncUpdate: Decodable {
    let id: String
    let title: String?
    let categoryID: String?
    let isCompleted: Bool
    let phase: Int
    let lastModifiedMillis: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case categoryID
        case isCompleted
        case phase
        case lastModifiedMillis
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title)
        categoryID = try container.decodeIfPresent(String.self, forKey: .categoryID)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        phase = try container.decodeIfPresent(Int.self, forKey: .phase) ?? 2
        lastModifiedMillis = try container.decodeIfPresent(Int64.self, forKey: .lastModifiedMillis) ?? 0
    }
}
