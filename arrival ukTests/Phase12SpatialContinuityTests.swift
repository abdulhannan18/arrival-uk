import XCTest
@testable import arrival_uk

final class Phase12SpatialContinuityTests: XCTestCase {
    func testDocumentActivityCarriesDocumentID() {
        let documentID = UUID()
        let activity = ArrivalWindowSceneBridge.documentActivity(for: documentID)
        let extracted = ArrivalWindowSceneBridge.documentID(from: activity)

        XCTAssertEqual(activity.activityType, ArrivalContinuity.openDocumentActivityType)
        XCTAssertEqual(extracted, documentID)
    }

    func testStagedPinnedDocumentIDRoundTrip() {
        let documentID = UUID()
        ArrivalWindowSceneBridge.stagePinnedDocumentID(documentID)

        XCTAssertEqual(ArrivalWindowSceneBridge.stagedPinnedDocumentID(), documentID)
    }
}
