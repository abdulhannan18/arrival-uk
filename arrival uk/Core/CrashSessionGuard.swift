import Foundation
import UIKit

enum CrashSessionGuard {
    private struct RecoverySnapshot: Codable {
        let capturedAt: Date
        let settledMode: Bool
        let survivalCount: Int
        let maintenanceCount: Int
    }

    private static let snapshotDefaultsKey = "crash.recovery.snapshot.v1"
    private static var didInstall = false
    private static var previousSessionWasUnclean = false
    private static let syncQueue = DispatchQueue(label: "com.arrivaluk.crash-session-guard")

    static func installIfNeeded() {
        syncQueue.sync {
            guard !didInstall else { return }
            didInstall = true
        }

        let defaults = UserDefaults.standard
        let didRunUnclean = defaults.bool(forKey: StorageKey.crashSessionInProgress.rawValue)
        previousSessionWasUnclean = didRunUnclean
        if didRunUnclean {
            defaults.set(Date(), forKey: StorageKey.crashLastUncleanAt.rawValue)
            CrashReporter.log("previous_session_unclean_exit_detected", level: .warning)
            TelemetryStore.shared.record(
                name: "previous_session_unclean_exit",
                level: .warning
            )
        }

        defaults.set(true, forKey: StorageKey.crashSessionInProgress.rawValue)

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            markSessionCleanExit()
        }
    }

    static func markSessionCleanExit() {
        UserDefaults.standard.set(false, forKey: StorageKey.crashSessionInProgress.rawValue)
    }

    static func updateRecoveryCheckpoint(
        settledMode: Bool,
        survivalCount: Int,
        maintenanceCount: Int
    ) {
        let snapshot = RecoverySnapshot(
            capturedAt: Date(),
            settledMode: settledMode,
            survivalCount: survivalCount,
            maintenanceCount: maintenanceCount
        )

        do {
            let encoded = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(encoded, forKey: snapshotDefaultsKey)
        } catch {
            CrashReporter.record(error: error, context: "crash_recovery_checkpoint_encode")
        }
    }

    static func restoreSettledModeIfNeeded(currentValue: Bool) -> Bool {
        guard previousSessionWasUnclean else { return currentValue }
        guard let snapshot = loadRecoverySnapshot() else { return currentValue }

        if snapshot.settledMode != currentValue {
            TelemetryStore.shared.record(
                name: "crash_recovery_settled_mode_restored",
                level: .warning,
                properties: [
                    "survivalCount": "\(snapshot.survivalCount)",
                    "maintenanceCount": "\(snapshot.maintenanceCount)"
                ]
            )
            CrashReporter.log(
                "crash_recovery_restored_settled_mode value=\(snapshot.settledMode ? 1 : 0)",
                level: .warning
            )
        }

        return snapshot.settledMode
    }

    private static func loadRecoverySnapshot() -> RecoverySnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(RecoverySnapshot.self, from: data)
    }
}
