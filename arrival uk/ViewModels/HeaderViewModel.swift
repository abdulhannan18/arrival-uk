import Foundation
import Observation

@Observable
final class HeaderViewModel {
    var userName: String
    var arrivalDate: Date
    var tasksCompletedPercentage: Int
    var currentDate: Date
    var isSettledMode: Bool

    init(
        userName: String = "Alex",
        arrivalDate: Date,
        tasksCompletedPercentage: Int = 0,
        currentDate: Date = .now,
        isSettledMode: Bool = false
    ) {
        self.userName = userName
        self.arrivalDate = arrivalDate
        self.tasksCompletedPercentage = tasksCompletedPercentage
        self.currentDate = currentDate
        self.isSettledMode = isSettledMode
    }

    var copilotStatusText: String {
        if isSettledMode {
            return "City Guide Mode • Explore perks near you"
        }

        let calendar = Calendar.current
        let startOfCurrentDate = calendar.startOfDay(for: currentDate)
        let startOfArrivalDate = calendar.startOfDay(for: arrivalDate)
        let daysUntil = calendar.dateComponents([.day], from: startOfCurrentDate, to: startOfArrivalDate).day ?? 0

        if daysUntil == 0 {
            return "Day 1 in the UK • Welcome to London"
        } else if daysUntil > 0 {
            return "Arrival in \(daysUntil) days • \(clampedCompletion)% Complete"
        } else {
            return "Day \(abs(daysUntil)) in the UK • \(clampedCompletion)% Complete"
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 6..<12:
            return "Good morning,"
        case 12..<17:
            return "Good afternoon,"
        default:
            return "Good evening,"
        }
    }

    private var clampedCompletion: Int {
        min(max(tasksCompletedPercentage, 0), 100)
    }
}
