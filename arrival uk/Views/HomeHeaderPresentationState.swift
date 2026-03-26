import Foundation

struct HomeHeaderPresentationState {
    let currentDate: Date
    let arrivalDate: Date
    let userDisplayName: String
    let streakCount: Int

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        return HomeLocalization.greeting(for: hour)
    }

    var dateBadgeText: String {
        UKLocaleFormat.mediumDateString(currentDate)
    }

    var greetingLine: String {
        "\(greetingText), \(userFirstName)"
    }

    var userFirstName: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return HomeLocalization.defaultFirstName }
        return trimmed.components(separatedBy: .whitespaces).first ?? trimmed
    }

    var dateContextLine: String {
        dateBadgeText
    }

    var arrivalStatusPillText: String? {
        if daysUntilArrival == 0 {
            return HomeLocalization.arrivingToday
        }
        if daysUntilArrival == 1 {
            return HomeLocalization.arrivingTomorrow
        }
        if (2...14).contains(daysUntilArrival) {
            return HomeLocalization.arrivingInDays(daysUntilArrival)
        }
        return nil
    }

    var streakPillText: String? {
        guard streakCount > 0 else { return nil }
        return HomeLocalization.streakLabel(days: streakCount)
    }

    var profileInitials: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "U" }

        let parts = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            let combined = "\(first)\(last)".uppercased()
            return combined.isEmpty ? "U" : combined
        }

        if let first = trimmed.first {
            return String(first).uppercased()
        }

        return "U"
    }

    var daysUntilArrival: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        let arrival = calendar.startOfDay(for: arrivalDate)
        return calendar.dateComponents([.day], from: today, to: arrival).day ?? 0
    }

    var profileAccessibilityLabel: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return HomeLocalization.openProfileLabel
        }
        return "\(HomeLocalization.openProfileLabel): \(trimmed)"
    }
}
