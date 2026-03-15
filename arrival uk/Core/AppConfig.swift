import Foundation

enum AppEnvironment: String {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

struct FeatureFlags {
    var enableAds: Bool
    var enableAffiliateLinks: Bool
    var enableCommunity: Bool
    var enableChat: Bool
    var enableDecorativeEffects: Bool

    static var `default`: FeatureFlags {
        FeatureFlags(
            enableAds: true,
            enableAffiliateLinks: true,
            enableCommunity: false,
            enableChat: false,
            enableDecorativeEffects: true
        )
    }
}

struct LegalConfiguration {
    let privacyPolicyURL: URL
    let termsOfServiceURL: URL
    let supportWebsiteURL: URL
    let supportEmailAddress: String
    let supportEmailSubject: String
    let dataDeletionRequestURL: URL

    var supportEmailURL: URL? {
        let subject = supportEmailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(supportEmailAddress)?subject=\(subject)")
    }
}

struct NetworkTrustConfiguration {
    let enforcePinning: Bool
    let allowUnpinnedHosts: Bool
    let pinnedCertificateHashesByHost: [String: Set<String>]
    let explicitlyAllowedUnpinnedHosts: Set<String>

    func pinnedHashes(for host: String) -> Set<String> {
        let normalizedHost = host.lowercased()
        if let direct = pinnedCertificateHashesByHost[normalizedHost] {
            return direct
        }

        // Allow wildcard host entries like "*.arrivaluk.app".
        for (configuredHost, hashes) in pinnedCertificateHashesByHost {
            guard configuredHost.hasPrefix("*.") else { continue }
            let suffix = String(configuredHost.dropFirst(1)) // ".arrivaluk.app"
            if normalizedHost.hasSuffix(suffix) {
                return hashes
            }
        }

        return []
    }

    func isExplicitlyAllowedUnpinnedHost(_ host: String) -> Bool {
        let normalizedHost = host.lowercased()
        if explicitlyAllowedUnpinnedHosts.contains(normalizedHost) {
            return true
        }

        for configuredHost in explicitlyAllowedUnpinnedHosts {
            guard configuredHost.hasPrefix("*.") else { continue }
            let suffix = String(configuredHost.dropFirst(1))
            if normalizedHost.hasSuffix(suffix) {
                return true
            }
        }

        return false
    }
}

enum AppConfig {
    private static func environmentOverride(_ key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }

        return nil
    }

    private static func httpsURLOverride(_ key: String) -> URL? {
        guard let override = environmentOverride(key) else {
            return nil
        }

        let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              parsed.scheme?.lowercased() == "https" else {
            return nil
        }
        return parsed
    }

    private static var legalBaseURL: URL {
        httpsURLOverride("ARRIVAL_LEGAL_BASE_URL") ?? RegionRuntime.legalBaseURL
    }

    private static func legalURL(_ path: String) -> URL {
        legalBaseURL.appendingPathComponent(path)
    }

    static var environment: AppEnvironment { .current }

    static var apiBaseURL: URL {
        if let override = httpsURLOverride("ARRIVAL_API_BASE_URL") {
            return override
        }

        switch environment {
        case .development:
            return httpsURLOverride("ARRIVAL_DEV_API_BASE_URL") ?? RegionRuntime.apiBaseURL
        case .staging:
            return httpsURLOverride("ARRIVAL_STAGING_API_BASE_URL") ?? RegionRuntime.apiBaseURL
        case .production:
            return RegionRuntime.apiBaseURL
        }
    }

    static var remoteConfigURL: URL {
        if let override = httpsURLOverride("ARRIVAL_REMOTE_CONFIG_URL") {
            return override
        }

        return apiBaseURL.appendingPathComponent("config.json")
    }

    static var collaborationWebSocketURL: URL? {
        if let override = environmentOverride("ARRIVAL_COLLAB_WS_URL") {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = URL(string: trimmed),
               parsed.scheme?.lowercased() == "wss" || parsed.scheme?.lowercased() == "ws" {
                return parsed
            }
        }

        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = (components.scheme?.lowercased() == "https") ? "wss" : "ws"
        components.path = "/v1/collaboration/realtime"
        return components.url
    }

    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let maxNetworkRetries: Int = 3
    static let launchWatchdogDelayNanoseconds: UInt64 = 1_500_000_000
    static let progressPersistDebounceNanoseconds: UInt64 = 350_000_000
    static let crashReportingEnabled = true
    static var networkTrust: NetworkTrustConfiguration {
        let googleCertificatePins: Set<String> = [
            // Google Trust Services WR2 intermediate
            "5v4iv0Xk8NO4XFngLA9JVBjh640yEPeI1IzV4ctUfNQ=",
            // Google Trust Services GTS Root R1
            "PuAnjfcfo8ElxM1IfwHXdGlOb8V+DNlMJO/XaRM5GOU="
        ]

        return NetworkTrustConfiguration(
            enforcePinning: environment == .production,
            // Only allow unknown hosts in non-production. Production should use pinning or explicit allow-list.
            allowUnpinnedHosts: environment != .production,
            pinnedCertificateHashesByHost: [
                "*.googleapis.com": googleCertificatePins
            ],
            explicitlyAllowedUnpinnedHosts: [
                "api.arrivaluk.app",
                "api-dev.arrivaluk.app",
                "api-staging.arrivaluk.app",
                "api.uk.arrival.com",
                "api.us.arrival.com",
                "api.ca.arrival.com",
                "api.au.arrival.com",
                "api.global.arrival.com",
                "*.arrivaluk.app",
                "*.arrival.com",
                // Firebase SDK networking does not route through `SecureHTTPClient`/URLSessionDelegate
                // pin evaluation. We explicitly allow these hosts and rely on App Check + Firebase
                // Security Rules as compensating controls.
                "*.cloudfunctions.net",
                "*.firebaseio.com"
            ]
        )
    }

    static var legal: LegalConfiguration {
        LegalConfiguration(
            privacyPolicyURL: legalURL("privacy"),
            termsOfServiceURL: legalURL("terms"),
            supportWebsiteURL: legalURL("support"),
            supportEmailAddress: "support@arrivaluk.app",
            supportEmailSubject: "Arrival UK Support Request",
            dataDeletionRequestURL: legalURL("delete-data")
        )
    }

    static var features: FeatureFlags {
        var value = FeatureFlags.default

        #if DEBUG
        value.enableCommunity = true
        #endif

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            value.enableDecorativeEffects = false
        }

        return value
    }
}
