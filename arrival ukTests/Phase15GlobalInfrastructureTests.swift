import XCTest
@testable import arrival_uk

final class Phase15GlobalInfrastructureTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        RegionRuntime.apply(phase15: .default)
        RegionRuntime.setActiveRegion(.uk)
    }

    func testPhase15ConfigDecodesAndActivatesUSIdentityRequirements() throws {
        let json = """
        {
          "phase_3_config": {
            "swipe_threshold": 160,
            "spring_damping": 0.8,
            "hero_card_limit": 1
          },
          "phase_4_wallet": {
            "required_docs": ["passport", "brp"],
            "biometric_enforced": true
          },
          "phase_14_marketplace": {
            "identity_token_ttl_seconds": 600,
            "providers": []
          },
          "phase_15_global": {
            "active_region": "usa",
            "fallback_region": "uk",
            "regions": [
              {
                "region": "usa",
                "display_name": "United States",
                "locale_identifier": "en_US",
                "currency_code": "USD",
                "date_format": "MMM d, yyyy",
                "national_id_label": "Social Security Number",
                "api_base_url": "https://api.us.arrival.com",
                "legal_base_url": "https://us.arrival.com",
                "identity_requirements": ["passport", "ssn"],
                "survival_task_boost_keywords": ["health insurance", "ssn"],
                "compliance_profile": "ccpa_cpra",
                "consent_requirements": ["terms_of_service", "privacy_policy", "do_not_sell"],
                "semantic_localization": {
                  "flat": "apartment",
                  "tube": "subway"
                },
                "asset_localization": {
                  "post_office": "mailbox"
                }
              }
            ]
          }
        }
        """

        let config = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        RegionRuntime.apply(phase15: config.phase15Global)

        XCTAssertEqual(RegionRuntime.activeRegion, .usa)
        XCTAssertEqual(RegionRuntime.activeConfiguration.currencyCode, "USD")
        XCTAssertTrue(RegionRuntime.activeConfiguration.identityRequirements.contains(.ssn))
    }

    func testMarketplaceProvidersAreFilteredByRegion() throws {
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
            "providers": [
              {
                "provider_id": "uk_bank",
                "display_name": "UK Bank",
                "service_type": "banking",
                "cta_title": "Open",
                "required_docs": ["passport", "brp"],
                "requested_fields": ["full_name"],
                "payment_mode": "none",
                "supported_regions": ["uk"]
              },
              {
                "provider_id": "us_bank",
                "display_name": "US Bank",
                "service_type": "banking",
                "cta_title": "Open",
                "required_docs": ["passport", "ssn"],
                "requested_fields": ["full_name"],
                "payment_mode": "none",
                "supported_regions": ["usa"]
              }
            ]
          },
          "phase_15_global": {
            "active_region": "usa",
            "fallback_region": "uk",
            "regions": []
          }
        }
        """

        let config = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        RegionRuntime.apply(phase15: config.phase15Global)

        let filtered = RegionRuntime.filterMarketplaceProviders(config.phase14Marketplace.providers)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.normalizedProviderID, "us_bank")
    }

    func testSemanticLocalizationAndSwipeDirectionFollowRegionalContext() {
        RegionRuntime.setActiveRegion(.usa)
        let localized = RegionRuntime.semanticLocalized("Find a flat near the tube")
        XCTAssertTrue(localized.localizedCaseInsensitiveContains("apartment"))
        XCTAssertTrue(localized.localizedCaseInsensitiveContains("subway"))

        let rtlDirection = RegionRuntime.completionSwipeDirection(forLayoutDirectionRTL: true)
        let ltrDirection = RegionRuntime.completionSwipeDirection(forLayoutDirectionRTL: false)
        XCTAssertEqual(rtlDirection, .leftToRight)
        XCTAssertEqual(ltrDirection, .rightToLeft)
    }
}
