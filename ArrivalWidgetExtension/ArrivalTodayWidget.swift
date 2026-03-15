import SwiftUI
import WidgetKit

struct ArrivalTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: ArrivalWidgetShared.Snapshot
    let currentTask: String
    let proximityDiscount: String?
    let deepLinkURL: URL?
}

struct ArrivalTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArrivalTodayEntry {
        let snapshot = ArrivalWidgetShared.fallbackSnapshot
        return ArrivalTodayEntry(
            date: .now,
            snapshot: snapshot,
            currentTask: snapshot.taskTitle,
            proximityDiscount: "10% off near campus",
            deepLinkURL: ArrivalWidgetShared.deepLinkURL(for: snapshot)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ArrivalTodayEntry) -> Void) {
        let snapshot = loadSnapshot()
        completion(makeEntry(snapshot: snapshot, at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArrivalTodayEntry>) -> Void) {
        let snapshot = loadSnapshot()
        let entry = makeEntry(snapshot: snapshot, at: .now)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> ArrivalWidgetShared.Snapshot {
        let defaults = UserDefaults(suiteName: ArrivalWidgetShared.appGroupID) ?? .standard
        guard let encoded = defaults.data(forKey: ArrivalWidgetShared.snapshotKey) else {
            return ArrivalWidgetShared.fallbackSnapshot
        }

        return (try? JSONDecoder().decode(ArrivalWidgetShared.Snapshot.self, from: encoded))
            ?? ArrivalWidgetShared.fallbackSnapshot
    }

    private func loadLocationContext() -> ArrivalWidgetShared.LocationContext {
        let defaults = UserDefaults(suiteName: ArrivalWidgetShared.appGroupID) ?? .standard
        guard let encoded = defaults.data(forKey: ArrivalWidgetShared.locationContextKey) else {
            return .unknown
        }
        guard let payload = try? JSONDecoder().decode(ArrivalWidgetShared.LocationSnapshot.self, from: encoded) else {
            return .unknown
        }

        // Ignore stale context to avoid showing outdated proximity info.
        if Date().timeIntervalSince(payload.updatedAt) > 2 * 60 * 60 {
            return .unknown
        }
        return payload.context
    }

    private func makeEntry(snapshot: ArrivalWidgetShared.Snapshot, at date: Date) -> ArrivalTodayEntry {
        let context = loadLocationContext()
        let resolved = resolvedContent(snapshot: snapshot, context: context, date: date)
        return ArrivalTodayEntry(
            date: date,
            snapshot: snapshot,
            currentTask: resolved.currentTask,
            proximityDiscount: resolved.proximityDiscount,
            deepLinkURL: resolved.deepLinkURL
        )
    }

    private func resolvedContent(
        snapshot: ArrivalWidgetShared.Snapshot,
        context: ArrivalWidgetShared.LocationContext,
        date: Date
    ) -> (currentTask: String, proximityDiscount: String?, deepLinkURL: URL?) {
        switch context {
        case .postOffice:
            return (
                "You're near a Post Office. Open your passport and CAS letter.",
                nil,
                ArrivalWidgetShared.walletDeepLinkURL(shouldUnlock: true)
            )
        case .highStreet:
            return (
                snapshot.taskTitle.isEmpty ? "Open Bank Account" : snapshot.taskTitle,
                "Nearby deal: 10% off at Boots",
                ArrivalWidgetShared.deepLinkURL(for: snapshot)
            )
        case .campus:
            return (
                "On campus: keep your Student ID and timetable ready.",
                "Student hub offers available nearby",
                ArrivalWidgetShared.deepLinkURL(for: snapshot)
            )
        case .unknown:
            let hour = Calendar.current.component(.hour, from: date)
            if hour < 12 {
                return (
                    snapshot.taskTitle.isEmpty ? "Open Arrival UK" : snapshot.taskTitle,
                    nil,
                    ArrivalWidgetShared.deepLinkURL(for: snapshot)
                )
            }

            if hour < 18 {
                return (
                    "Week 1 focus: \(snapshot.taskTitle)",
                    "Afternoon perk: Student lunch offers nearby",
                    ArrivalWidgetShared.deepLinkURL(for: snapshot)
                )
            }

            return (
                "Evening check: review tomorrow's UK tasks.",
                nil,
                ArrivalWidgetShared.deepLinkURL(for: snapshot)
            )
        }
    }
}

struct ArrivalTodayWidgetView: View {
    var entry: ArrivalTodayProvider.Entry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(widgetHex: entry.snapshot.categoryHex))

            LinearGradient(
                colors: [.clear, .black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Spacer()

                Text(entry.currentTask)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let proximityDiscount = entry.proximityDiscount {
                    Text(proximityDiscount)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                } else {
                    Text("~\(entry.snapshot.minutes)m")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .widgetURL(entry.deepLinkURL)
    }
}

struct ArrivalTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ArrivalWidgetShared.kind, provider: ArrivalTodayProvider()) { entry in
            ArrivalTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Task")
        .description("Your most important settlement task.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ArrivalTodayWidget()
} timeline: {
    ArrivalTodayEntry(
        date: .now,
        snapshot: ArrivalWidgetShared.fallbackSnapshot,
        currentTask: ArrivalWidgetShared.fallbackSnapshot.taskTitle,
        proximityDiscount: "10% off near campus",
        deepLinkURL: ArrivalWidgetShared.deepLinkURL(for: ArrivalWidgetShared.fallbackSnapshot)
    )
}
