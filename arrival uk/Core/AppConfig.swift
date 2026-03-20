import Foundation

private enum AppConfigurationRuntime {
    static var testingOverrides: [String: String] = [:]

    static func rawValue(for key: String) -> String? {
        if let override = testingOverrides[key], !override.isEmpty {
            return override
        }

        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }

        return nil
    }
}

enum AppEnvironment: String {
    case development
    case staging
    case production

    init?(configurationValue: String) {
        switch configurationValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development", "dev", "debug":
            self = .development
        case "staging", "stage", "preprod", "pre-production":
            self = .staging
        case "production", "prod", "release":
            self = .production
        default:
            return nil
        }
    }

    static var current: AppEnvironment {
        if let override = AppConfigurationRuntime.rawValue(for: "ARRIVAL_APP_ENV"),
           let resolved = AppEnvironment(configurationValue: override) {
            return resolved
        }

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

        for (configuredHost, hashes) in pinnedCertificateHashesByHost {
            guard configuredHost.hasPrefix("*.") else { continue }
            let suffix = String(configuredHost.dropFirst(1))
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
    static func setTestingOverride(_ value: String?, for key: String) {
        if let value {
            AppConfigurationRuntime.testingOverrides[key] = value
        } else {
            AppConfigurationRuntime.testingOverrides.removeValue(forKey: key)
        }
    }

    static func resetTestingOverrides() {
        AppConfigurationRuntime.testingOverrides.removeAll()
    }

    private static func environmentOverride(_ key: String) -> String? {
        AppConfigurationRuntime.rawValue(for: key)
    }

    private static func doubleOverride(_ key: String) -> Double? {
        guard let raw = environmentOverride(key) else { return nil }
        return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func intOverride(_ key: String) -> Int? {
        guard let raw = environmentOverride(key) else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func stringSetOverride(_ key: String) -> Set<String> {
        guard let raw = environmentOverride(key) else { return [] }
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
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

    static var marketplacePaymentConfirmationURL: URL {
        if let override = httpsURLOverride("ARRIVAL_MARKETPLACE_PAYMENT_CONFIRM_URL") {
            return override
        }

        return apiBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("marketplace")
            .appendingPathComponent("payments")
            .appendingPathComponent("confirm")
    }

    static var applePayMerchantID: String? {
        let trimmed = environmentOverride("ARRIVAL_APPLE_PAY_MERCHANT_ID")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static var collaborationWebSocketURL: URL? {
        if let override = environmentOverride("ARRIVAL_COLLAB_WS_URL") {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = URL(string: trimmed),
               let scheme = parsed.scheme?.lowercased(),
               scheme == "wss" || (scheme == "ws" && environment == .development) {
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

    static var requestTimeout: TimeInterval {
        min(max(doubleOverride("ARRIVAL_REQUEST_TIMEOUT_SECONDS") ?? 30, 5), 120)
    }

    static var resourceTimeout: TimeInterval {
        min(max(doubleOverride("ARRIVAL_RESOURCE_TIMEOUT_SECONDS") ?? 60, 10), 300)
    }

    static var maxNetworkRetries: Int {
        min(max(intOverride("ARRIVAL_MAX_NETWORK_RETRIES") ?? 3, 0), 8)
    }

    static var marketplaceAllowedProviderHosts: Set<String> {
        let configured = stringSetOverride("ARRIVAL_ALLOWED_MARKETPLACE_HOSTS")
        if !configured.isEmpty {
            return configured
        }

        switch environment {
        case .development:
            return []
        case .staging, .production:
            return [
                "arrivaluk.app",
                "www.arrivaluk.app",
                "api.arrivaluk.app",
                "*.arrivaluk.app",
                "*.arrival.com"
            ]
        }
    }

    static func isAllowedMarketplaceProviderHost(_ host: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHost.isEmpty else { return false }

        let allowlist = marketplaceAllowedProviderHosts
        if allowlist.isEmpty {
            return environment == .development
        }

        if allowlist.contains(normalizedHost) {
            return true
        }

        for configuredHost in allowlist where configuredHost.hasPrefix("*.") {
            let suffix = String(configuredHost.dropFirst(1))
            if normalizedHost.hasSuffix(suffix) {
                return true
            }
        }

        return false
    }

    static let launchWatchdogDelayNanoseconds: UInt64 = 1_500_000_000
    static let progressPersistDebounceNanoseconds: UInt64 = 350_000_000
    static let crashReportingEnabled = true
    static var networkTrust: NetworkTrustConfiguration {
        let googleCertificatePins: Set<String> = [
            "5v4iv0Xk8NO4XFngLA9JVBjh640yEPeI1IzV4ctUfNQ=",
            "PuAnjfcfo8ElxM1IfwHXdGlOb8V+DNlMJO/XaRM5GOU="
        ]
        let firstPartyPins = stringSetOverride("ARRIVAL_API_PINNED_SPKI_HASHES")
        if environment == .production && firstPartyPins.isEmpty {
            fatalError("Missing ARRIVAL_API_PINNED_SPKI_HASHES for production network pinning.")
        }

        var pinnedHashesByHost: [String: Set<String>] = [
            "*.googleapis.com": googleCertificatePins
        ]
        if !firstPartyPins.isEmpty {
            pinnedHashesByHost["api.arrivaluk.app"] = firstPartyPins
            pinnedHashesByHost["api-dev.arrivaluk.app"] = firstPartyPins
            pinnedHashesByHost["api-staging.arrivaluk.app"] = firstPartyPins
            pinnedHashesByHost["api.uk.arrival.com"] = firstPartyPins
            pinnedHashesByHost["api.us.arrival.com"] = firstPartyPins
            pinnedHashesByHost["api.ca.arrival.com"] = firstPartyPins
            pinnedHashesByHost["api.au.arrival.com"] = firstPartyPins
            pinnedHashesByHost["api.global.arrival.com"] = firstPartyPins
            pinnedHashesByHost["*.arrivaluk.app"] = firstPartyPins
            pinnedHashesByHost["*.arrival.com"] = firstPartyPins
        }

        var explicitlyAllowedUnpinnedHosts: Set<String> = [
            "*.cloudfunctions.net",
            "*.firebaseio.com"
        ]
        if environment != .production && firstPartyPins.isEmpty {
            explicitlyAllowedUnpinnedHosts.formUnion([
                "api.arrivaluk.app",
                "api-dev.arrivaluk.app",
                "api-staging.arrivaluk.app",
                "api.uk.arrival.com",
                "api.us.arrival.com",
                "api.ca.arrival.com",
                "api.au.arrival.com",
                "api.global.arrival.com",
                "*.arrivaluk.app",
                "*.arrival.com"
            ])
        }

        return NetworkTrustConfiguration(
            enforcePinning: environment == .production,
            allowUnpinnedHosts: environment != .production,
            pinnedCertificateHashesByHost: pinnedHashesByHost,
            explicitlyAllowedUnpinnedHosts: explicitlyAllowedUnpinnedHosts
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
