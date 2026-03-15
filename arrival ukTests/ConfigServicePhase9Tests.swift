import XCTest
@testable import arrival_uk

@MainActor
final class ConfigServicePhase9Tests: XCTestCase {
    func testRefreshFailureKeepsExistingConfigAsFallback() async {
        let defaults = makeIsolatedDefaults(name: "config.failure.\(UUID().uuidString)")
        let initialConfig = RemoteAppConfig(
            phase3: Phase3Config(swipeThreshold: 150, springDamping: 0.82, heroCardLimit: 2),
            phase4Wallet: Phase4WalletConfig(requiredDocuments: [.passport], biometricEnforced: true)
        )

        let service = ConfigService(
            defaults: defaults,
            bundle: .main,
            remoteFetcher: { _ in
                throw ConfigServiceError.remoteHTTPStatus(503)
            }
        )
        service.current = initialConfig
        service.source = .bundledDefault

        await service.refreshIfNeeded(reason: "test_failure", force: true)

        XCTAssertEqual(service.current, initialConfig)
        XCTAssertEqual(service.source, .bundledDefault)
        XCTAssertNil(defaults.data(forKey: StorageKey.remoteConfigCache.rawValue))
    }

    func testRefreshSuccessUpdatesCurrentAndPersistsCache() async {
        let defaults = makeIsolatedDefaults(name: "config.success.\(UUID().uuidString)")
        let remoteConfig = RemoteAppConfig(
            phase3: Phase3Config(swipeThreshold: 180, springDamping: 0.7, heroCardLimit: 1),
            phase4Wallet: Phase4WalletConfig(
                requiredDocuments: [.passport, .brp, .universityCAS, .tenancy],
                biometricEnforced: false
            )
        )

        let service = ConfigService(
            defaults: defaults,
            bundle: .main,
            remoteFetcher: { _ in remoteConfig }
        )

        await service.refreshIfNeeded(reason: "test_success", force: true)

        XCTAssertEqual(service.current, remoteConfig)
        XCTAssertEqual(service.source, .remote)
        XCTAssertNotNil(defaults.data(forKey: StorageKey.remoteConfigCache.rawValue))
        XCTAssertNotNil(defaults.object(forKey: StorageKey.remoteConfigUpdatedAt.rawValue) as? Date)
    }

    private func makeIsolatedDefaults(name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
