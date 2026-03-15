import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct ArrivalLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ArrivalActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: context.state.documentSymbol)
                        .font(.headline)
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(context.state.currentStep)
                    .font(.subheadline)
                    .lineLimit(2)

                ProgressView(value: min(max(context.state.progress, 0), 1))
                    .progressViewStyle(.linear)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.2))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.documentSymbol)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentStep)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int((context.state.progress * 100).rounded()))%")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: context.state.documentSymbol)
            } compactTrailing: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption2.bold())
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.documentSymbol)
            }
            .widgetURL(ArrivalWidgetShared.walletDeepLinkURL(shouldUnlock: true))
            .keylineTint(.white)
        }
    }
}
