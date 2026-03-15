import XCTest
@testable import arrival_uk

final class SmartAddInputEngineTests: XCTestCase {
    func testAnalyzeDetectsTravelCategoryAndDateFromNaturalPhrase() {
        let analysis = SmartAddInputEngine.analyze("Buy train tickets tomorrow")

        XCTAssertEqual(analysis.detectedCategoryID, "travel_transport")
        XCTAssertEqual(analysis.cleanedTitle, "Buy train tickets")
        XCTAssertNotNil(analysis.detectedDate)

        if let date = analysis.detectedDate {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfDetectedDay = calendar.startOfDay(for: date)
            let delta = calendar.dateComponents([.day], from: startOfToday, to: startOfDetectedDay).day ?? 0
            XCTAssertTrue(delta >= 1 && delta <= 2, "Expected tomorrow-ish date, got delta=\(delta)")
        }
    }

    func testAnalyzeDetectsHealthCategoryAndCleansDatePhrase() {
        let analysis = SmartAddInputEngine.analyze("Gym next Friday")

        XCTAssertEqual(analysis.detectedCategoryID, "health_admin")
        XCTAssertEqual(analysis.cleanedTitle, "Gym")
        XCTAssertNotNil(analysis.detectedDate)
    }

    func testAnalyzeLeavesUnknownCategoryAsNil() {
        let analysis = SmartAddInputEngine.analyze("Organize desk area")

        XCTAssertNil(analysis.detectedCategoryID)
        XCTAssertEqual(analysis.cleanedTitle, "Organize desk area")
    }

    func testAnalyzePreservesTitleWhenDatePhraseConsumesEntireInput() {
        let analysis = SmartAddInputEngine.analyze("tomorrow")

        XCTAssertEqual(analysis.cleanedTitle, "tomorrow")
        XCTAssertNotNil(analysis.detectedDate)
    }

    func testUrgencyBucketsMatchDueDateDistance() {
        XCTAssertEqual(SmartAddInputEngine.urgency(for: nil), .medium)

        let high = Date().addingTimeInterval(2 * 24 * 60 * 60)
        let medium = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let low = Date().addingTimeInterval(21 * 24 * 60 * 60)

        XCTAssertEqual(SmartAddInputEngine.urgency(for: high), .high)
        XCTAssertEqual(SmartAddInputEngine.urgency(for: medium), .medium)
        XCTAssertEqual(SmartAddInputEngine.urgency(for: low), .low)
    }

    func testCommitTaskAddsTaskToDetectedCategory() {
        let categories: [ChecklistCategory] = [
            ChecklistCategory(
                id: "before_arrival",
                title: "Before Arrival",
                icon: "airplane",
                tasks: []
            ),
            ChecklistCategory(
                id: "travel_transport",
                title: "Travel & Transport",
                icon: "tram",
                tasks: []
            )
        ]

        let result = SmartAddInputEngine.commitTask(
            rawInput: "Buy train tickets tomorrow",
            categories: categories,
            fallbackCategoryID: "before_arrival",
            detectedCategoryID: "travel_transport",
            detectedDate: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.categoryTitle, "Travel & Transport")
        XCTAssertEqual(result?.taskTitle, "Buy train tickets")
        XCTAssertEqual(result?.categories[1].tasks.count, 1)
        XCTAssertEqual(result?.categories[1].tasks.first?.title, "Buy train tickets")
        XCTAssertNotNil(result?.categories[1].tasks.first?.dueDate)
    }

    func testCommitTaskFallsBackToFallbackCategoryWhenNoDetection() {
        let categories: [ChecklistCategory] = [
            ChecklistCategory(
                id: "before_arrival",
                title: "Before Arrival",
                icon: "airplane",
                tasks: []
            ),
            ChecklistCategory(
                id: "work_career",
                title: "Work & Career",
                icon: "briefcase",
                tasks: []
            )
        ]

        let result = SmartAddInputEngine.commitTask(
            rawInput: "Organize desk area",
            categories: categories,
            fallbackCategoryID: "before_arrival",
            detectedCategoryID: nil,
            detectedDate: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.categoryTitle, "Before Arrival")
        XCTAssertEqual(result?.taskTitle, "Organize desk area")
        XCTAssertEqual(result?.categories[0].tasks.count, 1)
        XCTAssertEqual(result?.categories[1].tasks.count, 0)
    }

    func testCommitTaskReturnsNilForEmptyInputOrNoCategories() {
        let populatedCategories: [ChecklistCategory] = [
            ChecklistCategory(
                id: "before_arrival",
                title: "Before Arrival",
                icon: "airplane",
                tasks: []
            )
        ]

        XCTAssertNil(
            SmartAddInputEngine.commitTask(
                rawInput: "   ",
                categories: populatedCategories,
                fallbackCategoryID: "before_arrival",
                detectedCategoryID: nil,
                detectedDate: nil
            )
        )

        XCTAssertNil(
            SmartAddInputEngine.commitTask(
                rawInput: "Test task",
                categories: [],
                fallbackCategoryID: "before_arrival",
                detectedCategoryID: nil,
                detectedDate: nil
            )
        )
    }
}
