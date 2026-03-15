import XCTest
@testable import arrival_uk

final class HomeTimelineFilterTests: XCTestCase {
    func testNormalizedFilterKeepsCurrentWhenAvailable() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .beforeArrival, .weekOne]
        let normalized = ContentView.normalizedTimelineFilter(.weekOne, availableFilters: available)
        XCTAssertEqual(normalized, .weekOne)
    }

    func testNormalizedFilterFallsBackToAllWhenCurrentUnavailable() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .beforeArrival, .weekOne]
        let normalized = ContentView.normalizedTimelineFilter(.weekTwo, availableFilters: available)
        XCTAssertEqual(normalized, .all)
    }

    func testNormalizedFilterFallsBackToFirstWhenAllMissing() {
        let available: [ContentView.HomeTimelineFilter] = [.weekOne, .anytime]
        let normalized = ContentView.normalizedTimelineFilter(.weekTwo, availableFilters: available)
        XCTAssertEqual(normalized, .weekOne)
    }

    func testTimelineFilterSelectionRejectsUnknownID() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .weekOne]
        let selected = ContentView.timelineFilterSelection(for: "invalid_filter", availableFilters: available)
        XCTAssertNil(selected)
    }

    func testTimelineFilterSelectionRejectsUnavailableFilter() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .weekOne]
        let selected = ContentView.timelineFilterSelection(for: ContentView.HomeTimelineFilter.weekTwo.rawValue, availableFilters: available)
        XCTAssertNil(selected)
    }

    func testTimelineFilterSelectionAcceptsValidAvailableFilter() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .weekOne, .weekTwo]
        let selected = ContentView.timelineFilterSelection(for: ContentView.HomeTimelineFilter.weekTwo.rawValue, availableFilters: available)
        XCTAssertEqual(selected, .weekTwo)
    }

    func testTimelineFilterSelectionMapsWeekThreeAliasToWeekTwo() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .weekOne, .weekTwo]
        let selected = ContentView.timelineFilterSelection(for: "week3", availableFilters: available)
        XCTAssertEqual(selected, .weekTwo)
    }

    func testTimelineFilterSelectionMapsMonthOneAliasToWeekTwo() {
        let available: [ContentView.HomeTimelineFilter] = [.all, .weekOne, .weekTwo]
        let selected = ContentView.timelineFilterSelection(for: "month_1", availableFilters: available)
        XCTAssertEqual(selected, .weekTwo)
    }
}
