import XCTest
@testable import arrival_uk

final class HomeHeaderPresentationStateTests: XCTestCase {
    func testProfileInitialsUseFirstAndLastName() {
        let state = HomeHeaderPresentationState(
            currentDate: Date(timeIntervalSince1970: 0),
            arrivalDate: Date(timeIntervalSince1970: 0),
            userDisplayName: "Abdul Hannan",
            streakCount: 0
        )

        XCTAssertEqual(state.profileInitials, "AH")
    }

    func testArrivalStatusPillUsesLocalizedTomorrowLabel() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let state = HomeHeaderPresentationState(
            currentDate: today,
            arrivalDate: tomorrow,
            userDisplayName: "Arrival Student",
            streakCount: 0
        )

        XCTAssertEqual(state.arrivalStatusPillText, HomeLocalization.arrivingTomorrow)
    }

    func testProfileAccessibilityLabelFallsBackWhenNameIsEmpty() {
        let state = HomeHeaderPresentationState(
            currentDate: Date(timeIntervalSince1970: 0),
            arrivalDate: Date(timeIntervalSince1970: 0),
            userDisplayName: "   ",
            streakCount: 0
        )

        XCTAssertEqual(state.profileAccessibilityLabel, HomeLocalization.openProfileLabel)
        XCTAssertEqual(state.profileInitials, "U")
    }

    func testStreakPillTextUsesLocalizedLabel() {
        let state = HomeHeaderPresentationState(
            currentDate: Date(timeIntervalSince1970: 0),
            arrivalDate: Date(timeIntervalSince1970: 0),
            userDisplayName: "Arrival Student",
            streakCount: 5
        )

        XCTAssertEqual(state.streakPillText, HomeLocalization.streakLabel(days: 5))
    }
}
