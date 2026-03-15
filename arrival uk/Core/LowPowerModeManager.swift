import Foundation
import Observation

@MainActor
@Observable
final class LowPowerModeManager {
    static let shared = LowPowerModeManager()

    var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var isConfigured = false
    private var powerStateTask: Task<Void, Never>?

    private init() {}

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        powerStateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                guard !Task.isCancelled else { return }
                self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }
}
