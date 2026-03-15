import Foundation

enum ExternalURLPolicy {
    // Strict allow-list for plain HTTP. HTTPS is allowed globally.
    private static let trustedHTTPDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "ukcisa.org.uk",
        "nationalrail.co.uk",
        "maps.apple.com"
    ]

    // Stronger trust list used for content marked as official/university.
    static let trustedOfficialDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "ukri.org.uk",
        "ukfinance.org.uk",
        "ukcisa.org.uk",
        "nationalrail.co.uk"
    ]

    static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }
        return isAllowed(url) ? url : nil
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        switch scheme {
        case "https":
            return isValidHost(url.host)
        case "http":
            guard let host = url.host?.lowercased(), isValidHost(host) else { return false }
            return trustedHTTPDomainSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
        default:
            return false
        }
    }

    static func isTrustedOfficialOrUniversityHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        return trustedOfficialDomainSuffixes.contains { lowered == $0 || lowered.hasSuffix(".\($0)") }
    }

    private static func isValidHost(_ host: String?) -> Bool {
        guard let host = host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            return false
        }

        let lowered = host.lowercased()

        // Block localhost and obvious local-network targets for external navigation.
        if lowered == "localhost" || lowered.hasSuffix(".local") {
            return false
        }

        if lowered == "127.0.0.1" || lowered == "0.0.0.0" {
            return false
        }

        // Block direct IP address navigation (IPv4/IPv6). External content should use stable hostnames.
        if isIPAddress(lowered) {
            return false
        }

        return true
    }

    private static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") {
            // Treat any IPv6 literal as blocked (including "::1").
            return true
        }

        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard !part.isEmpty else { return false }
            guard let octet = Int(part), (0...255).contains(octet) else {
                return false
            }
        }

        return true
    }
}
