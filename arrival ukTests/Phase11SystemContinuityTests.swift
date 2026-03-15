import XCTest
@testable import arrival_uk

final class Phase11SystemContinuityTests: XCTestCase {
    func testWalletDeepLinkIncludesRequestedDocumentType() {
        let url = ArrivalWidgetSupport.walletDeepLinkURL(
            shouldUnlock: true,
            documentType: .studentVisa
        )

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let host = components?.host
        let unlock = components?.queryItems?.first(where: { $0.name == "unlock" })?.value
        let document = components?.queryItems?.first(where: { $0.name == "document" })?.value

        XCTAssertEqual(host, "wallet")
        XCTAssertEqual(unlock, "1")
        XCTAssertEqual(document, SecureDocType.studentVisa.rawValue)
    }

    func testQuickTaskDeepLinkUsesDedicatedHost() {
        let url = ArrivalWidgetSupport.quickTaskDeepLinkURL()
        XCTAssertEqual(url?.host, ArrivalWidgetSupport.quickTaskHost)
    }

    func testIntentBridgeRoundTripConsumesOnce() {
        let url = URL(string: "arrivaluk://quicktask")!
        ArrivalIntentRouteBridge.enqueue(deepLinkURL: url, source: "unit_test")

        let first = ArrivalIntentRouteBridge.consumePendingDeepLinkURL()
        let second = ArrivalIntentRouteBridge.consumePendingDeepLinkURL()

        XCTAssertEqual(first?.absoluteString, url.absoluteString)
        XCTAssertNil(second)
    }
}
