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
    let intermediateCAPinHashesByHost: [String: Set<String>]
    let explicitlyAllowedUnpinnedHosts: Set<String>

    func intermediateCAPinHashes(for host: String) -> Set<String> {
        let normalizedHost = host.lowercased()
        if let direct = intermediateCAPinHashesByHost[normalizedHost] {
            return direct
        }

        for (configuredHost, hashes) in intermediateCAPinHashesByHost {
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

    private static func boolOverride(_ key: String) -> Bool? {
        guard let raw = environmentOverride(key)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }

        switch raw {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
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

    private static func missingRequiredConfigMessage(for key: String) -> String {
        "Missing required config: \(key). Set \(key) in the active xcconfig. App cannot start safely without this value."
    }

    private static func logDebugConfigurationFallback(for key: String, stubDescription: String) {
        #if DEBUG
        NSLog("AppConfig debug fallback for %@. Using %@.", key, stubDescription)
        #endif
    }

    private static func requiredConfigString(_ key: String, debugStubValue: String) -> String {
        if let trimmed = environmentOverride(key)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        }

        #if DEBUG
        logDebugConfigurationFallback(for: key, stubDescription: "stub value")
        return debugStubValue
        #else
        fatalError(missingRequiredConfigMessage(for: key))
        #endif
    }

    private static func derivedCollaborationWebSocketURL(from baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = (components.scheme?.lowercased() == "https") ? "wss" : "ws"
        components.path = "/v1/collaboration/realtime"
        return components.url
    }

    private static var legalBaseURL: URL {
        httpsURLOverride("ARRIVAL_LEGAL_BASE_URL") ?? RegionRuntime.legalBaseURL
    }

    private static func legalURL(_ path: String) -> URL {
        legalBaseURL.appendingPathComponent(path)
    }

    static var environment: AppEnvironment { .current }

    static func validateRequiredConfiguration() {
        _ = applePayMerchantID
        if collaborationRealtimeEnabled {
            _ = collaborationWebSocketURL
        }
        _ = networkTrust
    }

    /// Realtime collaboration stays fail-closed until a room-scoped backend is explicitly enabled.
    static var collaborationRealtimeEnabled: Bool {
        boolOverride("ARRIVAL_ENABLE_COLLABORATION_REALTIME") ?? false
    }

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

    /// Release builds no longer return nil silently here: startup validation forces a fatal error,
    /// while DEBUG builds fall back to a documented stub merchant identifier.
    static var applePayMerchantID: String {
        requiredConfigString("ARRIVAL_APPLE_PAY_MERCHANT_ID", debugStubValue: "merchant.debug.arrivaluk")
    }

    /// Release builds no longer return nil silently here: startup validation forces a fatal error,
    /// while DEBUG builds fall back to a deterministic websocket stub so local builds stay runnable.
    static var collaborationWebSocketURL: URL {
        if let override = environmentOverride("ARRIVAL_COLLAB_WS_URL") {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = URL(string: trimmed),
               let scheme = parsed.scheme?.lowercased() {
                #if DEBUG
                if scheme == "wss" || scheme == "ws" {
                    return parsed
                }
                #else
                if scheme == "wss" {
                    return parsed
                }
                #endif
            }
        }

        #if DEBUG
        if let derived = derivedCollaborationWebSocketURL(from: apiBaseURL) {
            logDebugConfigurationFallback(for: "ARRIVAL_COLLAB_WS_URL", stubDescription: derived.absoluteString)
            return derived
        }
        logDebugConfigurationFallback(for: "ARRIVAL_COLLAB_WS_URL", stubDescription: "ws://localhost:8080/v1/collaboration/realtime")
        guard let debugStubURL = URL(string: "ws://localhost:8080/v1/collaboration/realtime") else {
            fatalError("Internal debug websocket stub URL is invalid.")
        }
        return debugStubURL
        #else
        fatalError(missingRequiredConfigMessage(for: "ARRIVAL_COLLAB_WS_URL"))
        #endif
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
        let intermediateCAPinHashes = stringSetOverride("ARRIVAL_API_PINNED_SPKI_HASHES")
        if environment == .production && intermediateCAPinHashes.isEmpty {
            fatalError("Missing ARRIVAL_API_PINNED_SPKI_HASHES for production network pinning.")
        }

        var pinnedHashesByHost: [String: Set<String>] = [
            "*.googleapis.com": googleCertificatePins
        ]
        if !intermediateCAPinHashes.isEmpty {
            pinnedHashesByHost["api.arrivaluk.app"] = intermediateCAPinHashes
            pinnedHashesByHost["api-dev.arrivaluk.app"] = intermediateCAPinHashes
            pinnedHashesByHost["api-staging.arrivaluk.app"] = intermediateCAPinHashes
            pinnedHashesByHost["api.uk.arrival.com"] = intermediateCAPinHashes
            pinnedHashesByHost["api.us.arrival.com"] = intermediateCAPinHashes
            pinnedHashesByHost["api.ca.arrival.com"] = intermediateCAPinHashes
            pinnedHashesByHost["api.au.arrival.com"] = intermediateCAPinHashes
            pinnedHashesByHost["api.global.arrival.com"] = intermediateCAPinHashes
            pinnedHashesByHost["*.arrivaluk.app"] = intermediateCAPinHashes
            pinnedHashesByHost["*.arrival.com"] = intermediateCAPinHashes
        }

        var explicitlyAllowedUnpinnedHosts: Set<String> = [
            "*.cloudfunctions.net",
            "*.firebaseio.com"
        ]
        if environment != .production && intermediateCAPinHashes.isEmpty {
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
            intermediateCAPinHashesByHost: pinnedHashesByHost,
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
