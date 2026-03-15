import XCTest
@testable import arrival_uk

final class Phase10IntelligenceTests: XCTestCase {
    func testDocumentClassifierDetectsBRPText() {
        let result = DocumentIntelligence.classify(
            recognizedText: "Biometric Residence Permit issued by UKVI",
            requestRevision: 3
        )

        XCTAssertEqual(result?.type, .studentVisa)
        XCTAssertNotNil(result?.confidence)
    }

    func testUrgencyPredictorElevatesLateBankingTask() {
        let predictor = TaskUrgencyPredictor.shared
        let task = AppTask(
            id: "hero-bank",
            taskID: "hero-bank",
            categoryID: "money_banking",
            categoryTitle: "Money & Banking",
            title: "Open your UK bank account",
            detail: nil,
            symbolName: "creditcard.fill",
            urgency: .high,
            priority: .mustDo,
            timing: .firstWeek,
            dueDate: nil,
            categoryUrgency: .week1,
            categoryOrder: 1,
            taskOrder: 1
        )

        let behindContext = TaskUrgencyContext(
            daysSinceArrival: 16,
            completedTaskCount: 2,
            totalTaskCount: 18,
            university: "UCL",
            city: "London"
        )
        let settledContext = TaskUrgencyContext(
            daysSinceArrival: 16,
            completedTaskCount: 16,
            totalTaskCount: 18,
            university: "UCL",
            city: "London"
        )

        let behindScore = predictor.predictUrgencyScore(for: task, context: behindContext)
        let settledScore = predictor.predictUrgencyScore(for: task, context: settledContext)

        XCTAssertGreaterThan(behindScore, settledScore)
        XCTAssertGreaterThan(behindScore, 0.8)
        XCTAssertTrue((0...1).contains(behindScore))
    }

    func testSemanticSearchPrefersIntentMatchingCandidate() {
        let candidates = [
            DiscoverySemanticCandidate(
                id: "groceries",
                title: "Discount Supermarkets",
                subtitle: "Cheap groceries near campus"
            ),
            DiscoverySemanticCandidate(
                id: "nightlife",
                title: "Nightlife Picks",
                subtitle: "Student events and bars"
            )
        ]

        let ranked = DiscoverySemanticSearch.rank(
            candidates: candidates,
            query: "where can I buy cheap groceries"
        )

        XCTAssertEqual(ranked.first, "groceries")
    }
}
