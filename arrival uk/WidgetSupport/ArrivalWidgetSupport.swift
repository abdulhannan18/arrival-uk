import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum ArrivalWidgetRoute: Equatable {
    struct TaskTarget: Equatable {
        let categoryID: String
        let taskID: String

        var isComplete: Bool {
            !categoryID.isEmpty && !taskID.isEmpty
        }
    }

    struct WalletTarget: Equatable {
        let shouldUnlock: Bool
        let documentType: SecureDocType?
    }

    case task(TaskTarget)
    case wallet(WalletTarget)
    case quickTask
    case discountQR

    init?(url: URL) {
        guard url.scheme?.lowercased() == ArrivalWidgetSupport.deepLinkScheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = components.host?.lowercased() ?? ""
        switch host {
        case "task":
            self = .task(
                TaskTarget(
                    categoryID: components.queryValue(named: "categoryID") ?? "",
                    taskID: components.queryValue(named: "taskID") ?? ""
                )
            )
        case "wallet":
            let unlockValue = components.queryValue(named: "unlock")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let shouldUnlock = unlockValue.map { ["1", "true", "yes", "y"].contains($0) } ?? true
            let documentType = SecureDocType.widgetRouteValue(components.queryValue(named: "document"))
            self = .wallet(
                WalletTarget(
                    shouldUnlock: shouldUnlock,
                    documentType: documentType
                )
            )
        case ArrivalWidgetSupport.quickTaskHost:
            self = .quickTask
        case ArrivalWidgetSupport.discountQRHost:
            self = .discountQR
        default:
            return nil
        }
    }
}

enum ArrivalWidgetSupport {
    static let kind = "ArrivalTodayWidget"
    static let appGroupID = "group.com.arrivaluk.shared"
    static let snapshotKey = "arrival.widget.snapshot.v1"
    static let locationContextKey = "arrival.widget.locationContext.v1"
    static let deepLinkScheme = "arrivaluk"
    static let quickTaskHost = "quicktask"
    static let discountQRHost = "discountqr"

    struct Snapshot: Codable {
        let taskTitle: String
        let minutes: Int
        let categoryHex: String
        let categoryID: String
        let taskID: String
        let updatedAt: Date
    }

    enum LocationContext: String, Codable {
        case campus
        case highStreet
        case postOffice
        case unknown
    }

    struct LocationSnapshot: Codable {
        let context: LocationContext
        let updatedAt: Date
    }

    static let fallbackSnapshot = Snapshot(
        taskTitle: "Open Arrival UK",
        minutes: 5,
        categoryHex: "1A3A8B",
        categoryID: "",
        taskID: "",
        updatedAt: .now
    )

    static func syncSnapshot(categories: [ChecklistCategory]) {
        let snapshot = mostUrgentSnapshot(from: categories) ?? fallbackSnapshot
        guard let encoded = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(encoded, forKey: snapshotKey)

        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(encoded, forKey: snapshotKey)
        }

        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    static func syncLocationContext(_ context: LocationContext) {
        let payload = LocationSnapshot(context: context, updatedAt: .now)
        guard let encoded = try? JSONEncoder().encode(payload) else { return }

        UserDefaults.standard.set(encoded, forKey: locationContextKey)
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(encoded, forKey: locationContextKey)
        }

        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    static func deepLinkURL(categoryID: String, taskID: String) -> URL? {
        guard !categoryID.isEmpty, !taskID.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = "task"
        components.queryItems = [
            URLQueryItem(name: "categoryID", value: categoryID),
            URLQueryItem(name: "taskID", value: taskID)
        ]
        return components.url
    }

    static func walletDeepLinkURL(shouldUnlock: Bool = true) -> URL? {
        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = "wallet"
        components.queryItems = [
            URLQueryItem(name: "unlock", value: shouldUnlock ? "1" : "0")
        ]
        return components.url
    }

    static func walletDeepLinkURL(
        shouldUnlock: Bool = true,
        documentType: SecureDocType?
    ) -> URL? {
        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = "wallet"

        var queryItems = [
            URLQueryItem(name: "unlock", value: shouldUnlock ? "1" : "0")
        ]
        if let documentType {
            queryItems.append(URLQueryItem(name: "document", value: documentType.rawValue))
        }
        components.queryItems = queryItems
        return components.url
    }

    static func quickTaskDeepLinkURL() -> URL? {
        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = quickTaskHost
        return components.url
    }

    static func discountQRDeepLinkURL() -> URL? {
        var components = URLComponents()
        components.scheme = deepLinkScheme
        components.host = discountQRHost
        return components.url
    }

    static func latestSnapshot() -> Snapshot? {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        if let sharedDefaults,
           let encoded = sharedDefaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: encoded) {
            return snapshot
        }

        guard let encoded = UserDefaults.standard.data(forKey: snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: encoded)
    }

    private static func mostUrgentSnapshot(from categories: [ChecklistCategory]) -> Snapshot? {
        let candidates: [(task: ChecklistTask, category: ChecklistCategory)] = categories.compactMap { category in
            guard !category.isCompleted else { return nil }
            guard let task = category.nextIncompleteTask else { return nil }
            return (task, category)
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            let leftUrgency = urgencyRank(for: lhs.category.urgencyBand)
            let rightUrgency = urgencyRank(for: rhs.category.urgencyBand)
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

        guard let candidate = sortedCandidates.first else {
            return nil
        }

        let categoryHex = resolvedHex(for: candidate.category)
        let minutes = max(1, candidate.task.estimatedMinutes ?? candidate.category.estimatedMinutes)

        return Snapshot(
            taskTitle: candidate.task.title,
            minutes: minutes,
            categoryHex: categoryHex,
            categoryID: candidate.category.id,
            taskID: candidate.task.id,
            updatedAt: .now
        )
    }

    private static func resolvedHex(for category: ChecklistCategory) -> String {
        let colorEntry = CategoryColorSystem.color(for: category, index: 0)
        return colorEntry.hex.replacingOccurrences(of: "#", with: "")
    }

    private static func priorityRank(for priority: TaskPriority) -> Int {
        switch priority {
        case .mustDo:
            return 0
        case .shouldDo:
            return 1
        case .optional:
            return 2
        }
    }

    private static func urgencyRank(for urgencyBand: CategoryUrgencyBand) -> Int {
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
}

private extension URLComponents {
    func queryValue(named name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}

private extension SecureDocType {
    static func widgetRouteValue(_ rawValue: String?) -> SecureDocType? {
        guard let rawValue else { return nil }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "passport":
            return .passport
        case "studentvisa", "visa", "brp":
            return .studentVisa
        case "casletter", "cas":
            return .casLetter
        case "tenancyagreement", "tenancy":
            return .tenancyAgreement
        case "nationalid", "ssn", "sin", "tfn":
            return .nationalID
        default:
            return SecureDocType(rawValue: rawValue)
        }
    }
}
