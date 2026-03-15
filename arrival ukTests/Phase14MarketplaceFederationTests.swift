import XCTest
@testable import arrival_uk

final class Phase14MarketplaceFederationTests: XCTestCase {
    func testIdentityTokenIsScopedAndExpires() {
        let issued = MarketplaceIdentityTokenService.issueTemporaryToken(
            providerID: "giffgaff_sim",
            userID: "student-123",
            requestedFields: [.fullName, .ukAddress],
            ttlSeconds: 120
        )

        XCTAssertNotNil(issued)
        guard let issued else { return }

        let payloadNow = MarketplaceIdentityTokenService.validateTemporaryToken(issued, now: .now)
        XCTAssertNotNil(payloadNow)
        XCTAssertEqual(payloadNow?.providerID, "giffgaff_sim")
        XCTAssertEqual(Set(payloadNow?.fieldScope ?? []), Set([.fullName, .ukAddress]))

        let expiryDate = Date().addingTimeInterval(180)
        let payloadExpired = MarketplaceIdentityTokenService.validateTemporaryToken(issued, now: expiryDate)
        XCTAssertNil(payloadExpired)
    }

    func testPhase14ConfigDecodesProviders() throws {
        let json = """
        {
          "phase_3_config": {
            "swipe_threshold": 160,
            "spring_damping": 0.8,
            "hero_card_limit": 1
          },
          "phase_4_wallet": {
            "required_docs": ["passport"],
            "biometric_enforced": true
          },
          "phase_14_marketplace": {
            "identity_token_ttl_seconds": 600,
            "providers": [{
              "provider_id": "monzo_student",
              "display_name": "Monzo",
              "service_type": "banking",
              "cta_title": "Open Bank Account",
              "required_docs": ["passport", "brp"],
              "requested_fields": ["full_name", "uk_address"],
              "payment_mode": "none"
            }]
          }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(RemoteAppConfig.self, from: data)
        XCTAssertEqual(config.phase14Marketplace.identityTokenTTLSeconds, 600)
        XCTAssertEqual(config.phase14Marketplace.providers.count, 1)
        XCTAssertEqual(config.phase14Marketplace.providers.first?.normalizedProviderID, "monzo_student")
    }
}
