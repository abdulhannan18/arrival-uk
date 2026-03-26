import XCTest
@testable import arrival_uk

final class ContentExternalURLRouteTests: XCTestCase {
    func testAllowedHTTPSURLPresentsInApp() {
        let url = URL(string: "https://arrivaluk.app/help")!

        XCTAssertEqual(ContentExternalURLRoute.resolve(for: url), .presentInApp)
    }

    func testBlockedLocalURLIsDiscarded() {
        let url = URL(string: "http://localhost:8080/debug")!

        XCTAssertEqual(ContentExternalURLRoute.resolve(for: url), .discard)
    }

    func testBlockedCustomSchemeIsDiscarded() {
        let url = URL(string: "javascript:alert('xss')")!

        XCTAssertEqual(ContentExternalURLRoute.resolve(for: url), .discard)
    }
}
