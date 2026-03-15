import XCTest
@testable import arrival_uk

final class TelemetryPIIRedactionTests: XCTestCase {
    func testSanitizeForTransportRedactsWalletAndIdentityKeys() {
        let sanitized = TelemetryStore.sanitizeForTransport([
            "passportNumber": "123456789",
            "brp_number": "0123456789",
            "casReference": "CAS-12345",
            "safeCounter": "3"
        ])

        XCTAssertEqual(sanitized["passportNumber"], "[redacted]")
        XCTAssertEqual(sanitized["brp_number"], "[redacted]")
        XCTAssertEqual(sanitized["casReference"], "[redacted]")
        XCTAssertEqual(sanitized["safeCounter"], "3")
    }

    func testSanitizeForTransportRedactsSensitiveValuesOnUnknownKeys() {
        let sanitized = TelemetryStore.sanitizeForTransport([
            "context": "AB123456C",
            "operator": "hello@arrivaluk.app",
            "tokenPreview": "ABC12345ZX"
        ])

        XCTAssertEqual(sanitized["context"], "[redacted]")
        XCTAssertEqual(sanitized["operator"], "[redacted]")
        XCTAssertEqual(sanitized["tokenPreview"], "[redacted]")
    }
}
