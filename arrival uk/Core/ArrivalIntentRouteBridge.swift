import Foundation

enum ArrivalIntentRouteBridge {
    struct Snapshot: Codable {
        let taskTitle: String
        let minutes: Int
        let categoryHex: String
        let categoryID: String
        let taskID: String
        let updatedAt: Date
    }

    private static let appGroupID = "group.com.arrivaluk.shared"
    private static let snapshotKey = "arrival.widget.snapshot.v1"
    private static let pendingDeepLinkKey = "arrival.intent.pendingDeepLink.v1"
    private static let pendingSourceKey = "arrival.intent.pendingSource.v1"

    static func enqueue(deepLinkURL: URL, source: String) {
        let defaults = sharedDefaults()
        defaults.set(deepLinkURL.absoluteString, forKey: pendingDeepLinkKey)
        defaults.set(source, forKey: pendingSourceKey)
        defaults.synchronize()
    }

    static func consumePendingDeepLinkURL() -> URL? {
        let defaults = sharedDefaults()
        defer {
            defaults.removeObject(forKey: pendingDeepLinkKey)
            defaults.removeObject(forKey: pendingSourceKey)
        }

        guard let rawURL = defaults.string(forKey: pendingDeepLinkKey),
              let url = URL(string: rawURL) else {
            return nil
        }
        return url
    }

    static func latestSnapshot() -> Snapshot? {
        let defaults = sharedDefaults()
        guard let encoded = defaults.data(forKey: snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Snapshot.self, from: encoded)
    }

    private static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
