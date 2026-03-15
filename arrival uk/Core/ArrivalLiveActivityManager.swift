import ActivityKit
import Foundation

@MainActor
@available(iOS 16.2, *)
final class ArrivalLiveActivityManager {
    static let shared = ArrivalLiveActivityManager()

    private var activeActivity: Activity<ArrivalActivityAttributes>?

    private init() {}

    func startOrUpdate(
        taskTitle: String,
        currentStep: String,
        progress: Double,
        documentSymbol: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let clampedProgress = min(max(progress, 0), 1)
        let state = ArrivalActivityAttributes.ContentState(
            currentStep: currentStep,
            progress: clampedProgress,
            documentSymbol: documentSymbol
        )

        let content = ActivityContent(state: state, staleDate: nil)

        if let activity = activeActivity ?? Activity<ArrivalActivityAttributes>.activities.first {
            await activity.update(content)
            activeActivity = activity
            return
        }

        let attributes = ArrivalActivityAttributes(taskTitle: taskTitle)
        do {
            activeActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            CrashReporter.record(error: error, context: "live_activity_start")
        }
    }

    func endCurrentIfNeeded() async {
        guard let activity = activeActivity ?? Activity<ArrivalActivityAttributes>.activities.first else {
            return
        }
        await activity.end(nil, dismissalPolicy: .immediate)
        activeActivity = nil
    }
}
