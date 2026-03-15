import Foundation

@inline(__always)
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAILED: \(message)\n", stderr)
        Foundation.exit(1)
    }
}

@main
struct IOSUnitSmokeTests {
    static func main() {
        // HTTPS should be allowed for valid remote hosts.
        let httpsURL = URL(string: "https://www.gov.uk/")!
        expect(ExternalURLPolicy.isAllowed(httpsURL), "HTTPS URL should be allowed")

        // HTTP is only allowed for trusted allowlist suffixes.
        let trustedHTTPURL = URL(string: "http://www.gov.uk/")!
        let untrustedHTTPURL = URL(string: "http://example.com/")!
        expect(ExternalURLPolicy.isAllowed(trustedHTTPURL), "Trusted HTTP domain should be allowed")
        expect(!ExternalURLPolicy.isAllowed(untrustedHTTPURL), "Untrusted HTTP domain should be blocked")

        // Non-http schemes must be blocked.
        let ftpURL = URL(string: "ftp://gov.uk/file")!
        expect(!ExternalURLPolicy.isAllowed(ftpURL), "Unsupported URL schemes must be blocked")

        // Local hosts should be blocked even with HTTPS.
        let localhostURL = URL(string: "https://localhost/path")!
        expect(!ExternalURLPolicy.isAllowed(localhostURL), "Localhost should be blocked")

        // Normalization should trim and validate.
        expect(
            ExternalURLPolicy.normalizedURL(from: "  https://www.nhs.uk/  ")?.absoluteString == "https://www.nhs.uk/",
            "normalizedURL should trim and preserve valid URLs"
        )
        expect(
            ExternalURLPolicy.normalizedURL(from: "javascript:alert(1)") == nil,
            "normalizedURL should reject unsupported schemes"
        )

        // Official host trust list should include known UK domains.
        expect(
            ExternalURLPolicy.isTrustedOfficialOrUniversityHost("www.ac.uk"),
            "University domain suffix should be trusted"
        )
        expect(
            !ExternalURLPolicy.isTrustedOfficialOrUniversityHost("example.com"),
            "Untrusted host should not be marked official"
        )

        print("ios_unit_smoke_tests passed")
    }
}
