import Foundation

enum AppTiming {
    static let profileHelpSheetPresentationDelay: Duration = .milliseconds(280)
    static let progressPersistenceCoalescingDelay: Duration = .milliseconds(350)
    static let contentProgressPersistenceCoalescingDelay: Duration = .milliseconds(150)
    static let decorativeEffectsEnableDelay: Duration = .milliseconds(180)
    static let scrollIdleResetDelay: Duration = .milliseconds(180)
    static let toastAutoDismissDelay: Duration = .seconds(1.8)
    static let hapticEchoDelay: Duration = .milliseconds(80)
    static let markHomeLaunchConsumedDelay: Duration = .milliseconds(900)
    static let bootstrapWatchdogDelay: Duration = .seconds(3)
    static let homeClockTickInterval: Duration = .seconds(60)
    static let categoryOverlayTransitionDelay: Duration = .milliseconds(280)
    static let smartAddFocusDelay: Duration = .milliseconds(90)
}
