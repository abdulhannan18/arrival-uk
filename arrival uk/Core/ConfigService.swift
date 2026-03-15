import Foundation
import Observation

enum ConfigSource: String {
    case hardcodedFallback
    case bundledDefault
    case cached
    case remote
}

enum ConfigServiceError: LocalizedError {
    case insecureRemoteURL(String)
    case invalidRemoteResponse
    case remoteHTTPStatus(Int)
    case remoteDecoding(Error)

    var errorDescription: String? {
        switch self {
        case .insecureRemoteURL(let value):
            return "Remote config URL must use HTTPS: \(value)"
        case .invalidRemoteResponse:
            return "Remote config endpoint returned an invalid response."
        case .remoteHTTPStatus(let statusCode):
            return "Remote config endpoint returned HTTP \(statusCode)."
        case .remoteDecoding:
            return "Remote config payload could not be decoded."
        }
    }
}

@MainActor
@Observable
final class ConfigService {
    typealias RemoteFetcher = @MainActor @Sendable (URL) async throws -> RemoteAppConfig

    static let shared = ConfigService()

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let remoteFetcher: RemoteFetcher
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let minimumRefreshInterval: TimeInterval = 15 * 60
    private var isConfigured = false
    private var isRefreshInFlight = false
    private var lastRefreshAttemptAt: Date?

    var current = RemoteAppConfig.default
    var source: ConfigSource = .hardcodedFallback
    var lastUpdatedAt: Date?

    var activeRegion: ArrivalRegion {
        RegionRuntime.activeRegion
    }

    var activeRegionConfiguration: RegionConfiguration {
        RegionRuntime.activeConfiguration
    }

    var effectivePhase4WalletConfig: Phase4WalletConfig {
        let regionIdentityRequirements = activeRegionConfiguration.identityRequirements
        guard !regionIdentityRequirements.isEmpty else {
            return current.phase4Wallet
        }
        return Phase4WalletConfig(
            requiredDocuments: regionIdentityRequirements,
            biometricEnforced: current.phase4Wallet.biometricEnforced
        )
    }

    var effectiveMarketplaceProviders: [MarketplaceProviderDescriptor] {
        RegionRuntime.filterMarketplaceProviders(current.phase14Marketplace.providers)
    }

    var activeConsentRequirements: [RegionalConsentRequirement] {
        activeRegionConfiguration.consentRequirements
    }

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        remoteFetcher: @escaping RemoteFetcher = ConfigService.defaultRemoteFetcher
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.remoteFetcher = remoteFetcher
        encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        loadBundledDefaultIfAvailable()
        loadCachedConfigIfAvailable()

        Task {
            await refreshIfNeeded(reason: "startup", force: false)
        }
    }

    func refreshIfNeeded(reason: String, force: Bool) async {
        guard !isRefreshInFlight else { return }

        if !force,
           let lastRefreshAttemptAt,
           Date().timeIntervalSince(lastRefreshAttemptAt) < minimumRefreshInterval {
            return
        }

        isRefreshInFlight = true
        lastRefreshAttemptAt = Date()
        defer { isRefreshInFlight = false }

        do {
            let remoteConfig = try await remoteFetcher(AppConfig.remoteConfigURL)
            apply(config: remoteConfig, source: .remote)
            persistCachedConfig(remoteConfig)

            TelemetryStore.shared.record(
                name: "remote_config_refresh_success",
                level: .info,
                properties: [
                    "reason": reason,
                    "source": source.rawValue
                ]
            )
        } catch {
            CrashReporter.record(error: error, context: "remote_config_refresh_\(reason)")
            TelemetryStore.shared.record(
                name: "remote_config_refresh_failed",
                level: .warning,
                properties: [
                    "reason": reason
                ]
            )
        }
    }

    private func apply(config: RemoteAppConfig, source: ConfigSource) {
        RegionRuntime.apply(phase15: config.phase15Global)
        current = config
        self.source = source
        lastUpdatedAt = Date()
    }

    private func loadBundledDefaultIfAvailable() {
        let directURL = bundle.url(forResource: "DefaultConfig", withExtension: "json")
        let dataURL = bundle.url(forResource: "DefaultConfig", withExtension: "json", subdirectory: "Data")
        guard let url = directURL ?? dataURL else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode(RemoteAppConfig.self, from: data)
            apply(config: decoded, source: .bundledDefault)
        } catch {
            CrashReporter.record(error: error, context: "bundled_config_decode")
        }
    }

    private func loadCachedConfigIfAvailable() {
        guard let data = defaults.data(forKey: StorageKey.remoteConfigCache.rawValue) else { return }

        do {
            let decoded = try decoder.decode(RemoteAppConfig.self, from: data)
            apply(config: decoded, source: .cached)
            if let timestamp = defaults.object(forKey: StorageKey.remoteConfigUpdatedAt.rawValue) as? Date {
                lastUpdatedAt = timestamp
            } else {
                lastUpdatedAt = Date()
            }
        } catch {
            defaults.removeObject(forKey: StorageKey.remoteConfigCache.rawValue)
            defaults.removeObject(forKey: StorageKey.remoteConfigUpdatedAt.rawValue)
            CrashReporter.record(error: error, context: "cached_config_decode")
        }
    }

    private func persistCachedConfig(_ config: RemoteAppConfig) {
        do {
            let data = try encoder.encode(config)
            defaults.set(data, forKey: StorageKey.remoteConfigCache.rawValue)
            defaults.set(Date(), forKey: StorageKey.remoteConfigUpdatedAt.rawValue)
        } catch {
            CrashReporter.record(error: error, context: "cached_config_encode")
        }
    }

    static func defaultRemoteFetcher(url: URL) async throws -> RemoteAppConfig {
        guard url.scheme?.lowercased() == "https" else {
            throw ConfigServiceError.insecureRemoteURL(url.absoluteString)
        }

        if #available(iOS 17.0, *) {
            return try await SecureHTTPClient.shared.request(endpoint: url.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = AppConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigServiceError.invalidRemoteResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ConfigServiceError.remoteHTTPStatus(httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode(RemoteAppConfig.self, from: data)
        } catch {
            throw ConfigServiceError.remoteDecoding(error)
        }
    }
}
