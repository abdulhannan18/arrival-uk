import Foundation

final class StreakManager {
    enum Keys {
        static let encryptedState = StorageKey.homeCompletionStreakEncrypted.rawValue
        static let encryptionKey = StorageKey.homeCompletionStreakEncryptionKey.rawValue
        static let streak = StorageKey.homeCompletionStreakLegacy.rawValue
        static let lastActiveDate = StorageKey.homeCompletionStreakLastActiveLegacy.rawValue
    }

    private struct Snapshot: Codable {
        let streak: Int
        let lastActiveDate: TimeInterval?
    }

    static let shared = StreakManager()

    private let defaults: UserDefaults
    private var calendar: Calendar

    private init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var currentStreak: Int { loadSnapshot().streak }

    func recordTaskCompletion(now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        let snapshot = loadSnapshot()

        let previousReference = snapshot.lastActiveDate ?? 0
        let normalizedPreviousDate = previousReference > 0
            ? Date(timeIntervalSince1970: previousReference)
            : nil

        let previousDay = normalizedPreviousDate.map { calendar.startOfDay(for: $0) }
        let dayDelta = previousDay.map {
            calendar.dateComponents([.day], from: $0, to: today).day ?? 0
        } ?? Int.max

        let updatedStreak: Int
        switch dayDelta {
        case 0:
            updatedStreak = max(1, snapshot.streak)
        case 1:
            updatedStreak = max(1, snapshot.streak + 1)
        default:
            updatedStreak = 1
        }

        persistSnapshot(
            Snapshot(
                streak: updatedStreak,
                lastActiveDate: today.timeIntervalSince1970
            )
        )
    }

    private func loadSnapshot() -> Snapshot {
        if let encryptedData = try? EncryptedDefaultsStore.load(
            for: Keys.encryptedState,
            keychainKey: Keys.encryptionKey,
            defaults: defaults
        ), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: encryptedData) {
            return Snapshot(
                streak: max(0, snapshot.streak),
                lastActiveDate: snapshot.lastActiveDate
            )
        }

        let legacyStreak = max(0, defaults.integer(forKey: Keys.streak))
        let legacyLastActiveRaw = defaults.double(forKey: Keys.lastActiveDate)
        let legacyLastActive = legacyLastActiveRaw > 0 ? legacyLastActiveRaw : nil

        let migratedSnapshot = Snapshot(
            streak: legacyStreak,
            lastActiveDate: legacyLastActive
        )

        if legacyStreak > 0 || legacyLastActive != nil {
            persistSnapshot(migratedSnapshot)
        }

        return migratedSnapshot
    }

    private func persistSnapshot(_ snapshot: Snapshot) {
        do {
            let encoded = try JSONEncoder().encode(snapshot)
            try EncryptedDefaultsStore.save(
                encoded,
                for: Keys.encryptedState,
                keychainKey: Keys.encryptionKey,
                defaults: defaults
            )

            defaults.removeObject(forKey: Keys.streak)
            defaults.removeObject(forKey: Keys.lastActiveDate)
        } catch {
            // Legacy fallback keeps streak updates functional if encryption fails.
            defaults.set(snapshot.streak, forKey: Keys.streak)
            defaults.set(snapshot.lastActiveDate ?? 0, forKey: Keys.lastActiveDate)
        }
    }
}
