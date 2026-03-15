import Foundation
import UserNotifications

/// Handles local reminder scheduling for checklist tasks.
/// Requires iOS 17.0+
@available(iOS 17.0, *)
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let dailyIdentifier = "arrival.daily"
    private let criticalIdentifierPrefix = "arrival.critical"
    private let collaborationUrgentIdentifierPrefix = "arrival.collaboration.urgent"
    private let preferredHourKey = StorageKey.notificationsDailyHour.rawValue
    private let preferredMinuteKey = StorageKey.notificationsDailyMinute.rawValue
    private let criticalLastTaskIDKey = StorageKey.notificationsCriticalLastTaskID.rawValue
    private let criticalLastSentAtKey = StorageKey.notificationsCriticalLastSentAt.rawValue
    private let collaborationUrgentLastTaskIDKey = StorageKey.notificationsCollaborativeUrgentLastTaskID.rawValue
    private let collaborationUrgentLastSentAtKey = StorageKey.notificationsCollaborativeUrgentLastSentAt.rawValue
    private let defaultReminderHour = 9
    private let defaultReminderMinute = 0
    private let criticalCooldownSeconds: TimeInterval = 4 * 60 * 60
    private let collaborationUrgentCooldownSeconds: TimeInterval = 20 * 60

    private init() {}

    func requestPermissionIfNeeded(promptIfUndetermined: Bool = true) async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard promptIfUndetermined else { return false }
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                CrashReporter.record(
                    error: error,
                    context: "notification_permission_request"
                )
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func refreshTaskReminders(categories: [ChecklistCategory]) async {
        let isAuthorized = await requestPermissionIfNeeded(promptIfUndetermined: false)
        guard isAuthorized else { return }
        await removePendingDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Arrival UK"
        content.body = mostUrgentTaskTitle(from: categories) ?? "You have settlement tasks waiting."
        content.sound = .default
        content.userInfo = ["type": "daily_urgent"]

        var components = DateComponents()
        components.hour = preferredReminderHour
        components.minute = preferredReminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            await MainActor.run {
                CrashReporter.record(
                    error: error,
                    context: "notification_schedule_daily"
                )
            }
        }
    }

    func updatePreferredReminderTime(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return }
        UserDefaults.standard.set(hour, forKey: preferredHourKey)
        UserDefaults.standard.set(minute, forKey: preferredMinuteKey)
    }

    func cancelAllReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
    }

    func scheduleCriticalUrgencyAlert(task: AppTask, score: Double) async {
        let isAuthorized = await requestPermissionIfNeeded(promptIfUndetermined: false)
        guard isAuthorized else { return }
        guard shouldSendCriticalAlert(taskID: task.taskID, now: .now) else { return }

        let identifier = "\(criticalIdentifierPrefix).\(task.taskID)"
        let content = UNMutableNotificationContent()
        content.title = "Critical Priority"
        content.body = "You're at risk of falling behind: \(task.title)"
        content.sound = .default
        content.userInfo = [
            "type": "critical_urgency",
            "taskID": task.taskID
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            try await center.add(request)
            markCriticalAlertSent(taskID: task.taskID, now: .now)

            TelemetryStore.shared.record(
                name: "critical_urgency_notification_scheduled",
                level: .warning,
                properties: [
                    "taskID": task.taskID,
                    "score": String(format: "%.2f", score)
                ]
            )
        } catch {
            await MainActor.run {
                CrashReporter.record(
                    error: error,
                    context: "notification_schedule_critical"
                )
            }
        }
    }

    func scheduleCollaborativeUrgentAlert(taskTitle: String, taskID: String) async {
        let isAuthorized = await requestPermissionIfNeeded(promptIfUndetermined: false)
        guard isAuthorized else { return }
        guard shouldSendCollaborativeUrgentAlert(taskID: taskID, now: .now) else { return }

        let identifier = "\(collaborationUrgentIdentifierPrefix).\(taskID)"
        let content = UNMutableNotificationContent()
        content.title = "Roommate Completed a Priority Task"
        content.body = "\(taskTitle) was updated in your shared journey."
        content.sound = .default
        content.userInfo = [
            "type": "collaboration_urgent",
            "taskID": taskID
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            try await center.add(request)
            markCollaborativeUrgentAlertSent(taskID: taskID, now: .now)
        } catch {
            await MainActor.run {
                CrashReporter.record(error: error, context: "notification_schedule_collaboration_urgent")
            }
        }
    }

    private func removePendingDailyReminder() async {
        let pendingRequests = await center.pendingNotificationRequests()
        guard pendingRequests.contains(where: { $0.identifier == dailyIdentifier }) else { return }
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
    }

    private var preferredReminderHour: Int {
        let stored = UserDefaults.standard.integer(forKey: preferredHourKey)
        if (0...23).contains(stored) {
            return stored
        }
        return defaultReminderHour
    }

    private var preferredReminderMinute: Int {
        let stored = UserDefaults.standard.integer(forKey: preferredMinuteKey)
        if (0...59).contains(stored) {
            return stored
        }
        return defaultReminderMinute
    }

    private func shouldSendCriticalAlert(taskID: String, now: Date) -> Bool {
        let defaults = UserDefaults.standard
        let lastTaskID = defaults.string(forKey: criticalLastTaskIDKey)
        let lastSentAt = defaults.object(forKey: criticalLastSentAtKey) as? Date

        if lastTaskID == taskID,
           let lastSentAt,
           now.timeIntervalSince(lastSentAt) < criticalCooldownSeconds {
            return false
        }
        return true
    }

    private func markCriticalAlertSent(taskID: String, now: Date) {
        let defaults = UserDefaults.standard
        defaults.set(taskID, forKey: criticalLastTaskIDKey)
        defaults.set(now, forKey: criticalLastSentAtKey)
    }

    private func shouldSendCollaborativeUrgentAlert(taskID: String, now: Date) -> Bool {
        let defaults = UserDefaults.standard
        let lastTaskID = defaults.string(forKey: collaborationUrgentLastTaskIDKey)
        let lastSentAt = defaults.object(forKey: collaborationUrgentLastSentAtKey) as? Date

        if lastTaskID == taskID,
           let lastSentAt,
           now.timeIntervalSince(lastSentAt) < collaborationUrgentCooldownSeconds {
            return false
        }
        return true
    }

    private func markCollaborativeUrgentAlertSent(taskID: String, now: Date) {
        let defaults = UserDefaults.standard
        defaults.set(taskID, forKey: collaborationUrgentLastTaskIDKey)
        defaults.set(now, forKey: collaborationUrgentLastSentAtKey)
    }

    private func priorityRank(for priority: TaskPriority) -> Int {
        switch priority {
        case .mustDo:
            return 0
        case .shouldDo:
            return 1
        case .optional:
            return 2
        }
    }

    private func categoryUrgencyRank(_ urgencyBand: CategoryUrgencyBand) -> Int {
        switch urgencyBand {
        case .immediate:
            return 0
        case .week1:
            return 1
        case .week2:
            return 2
        case .anytime:
            return 3
        case .completed:
            return 4
        }
    }

    private func mostUrgentTaskTitle(from categories: [ChecklistCategory]) -> String? {
        typealias Candidate = (task: ChecklistTask, category: ChecklistCategory)
        let candidates: [Candidate] = categories.compactMap { category in
            guard !category.isCompleted else { return nil }
            guard let task = category.nextIncompleteTask else { return nil }
            return (task, category)
        }

        guard !candidates.isEmpty else { return nil }

        let sorted = candidates.sorted { lhs, rhs in
            let leftUrgency = categoryUrgencyRank(lhs.category.urgencyBand)
            let rightUrgency = categoryUrgencyRank(rhs.category.urgencyBand)
            if leftUrgency != rightUrgency {
                return leftUrgency < rightUrgency
            }

            let leftPriority = priorityRank(for: lhs.task.priority)
            let rightPriority = priorityRank(for: rhs.task.priority)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            switch (lhs.task.dueDate, rhs.task.dueDate) {
            case (.some(let leftDate), .some(let rightDate)):
                if leftDate != rightDate {
                    return leftDate < rightDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            let leftOrder = lhs.task.order ?? .max
            let rightOrder = rhs.task.order ?? .max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            return lhs.task.id < rhs.task.id
        }

        return sorted.first?.task.title
    }
}
