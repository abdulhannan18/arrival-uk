import Foundation

struct RemoteAppConfig: Codable, Equatable, Sendable {
    var phase3: Phase3Config
    var phase4Wallet: Phase4WalletConfig
    var phase14Marketplace: Phase14MarketplaceConfig
    var phase15Global: Phase15GlobalConfig

    enum CodingKeys: String, CodingKey {
        case phase3 = "phase_3_config"
        case phase4Wallet = "phase_4_wallet"
        case phase14Marketplace = "phase_14_marketplace"
        case phase15Global = "phase_15_global"
    }

    static let `default` = RemoteAppConfig(
        phase3: .default,
        phase4Wallet: .default,
        phase14Marketplace: .default,
        phase15Global: .default
    )

    init(
        phase3: Phase3Config = .default,
        phase4Wallet: Phase4WalletConfig = .default,
        phase14Marketplace: Phase14MarketplaceConfig = .default,
        phase15Global: Phase15GlobalConfig = .default
    ) {
        self.phase3 = phase3
        self.phase4Wallet = phase4Wallet
        self.phase14Marketplace = phase14Marketplace
        self.phase15Global = phase15Global
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            phase3: try container.decodeIfPresent(Phase3Config.self, forKey: .phase3) ?? .default,
            phase4Wallet: try container.decodeIfPresent(Phase4WalletConfig.self, forKey: .phase4Wallet) ?? .default,
            phase14Marketplace: try container.decodeIfPresent(Phase14MarketplaceConfig.self, forKey: .phase14Marketplace) ?? .default,
            phase15Global: try container.decodeIfPresent(Phase15GlobalConfig.self, forKey: .phase15Global) ?? .default
        )
    }
}

struct Phase3Config: Codable, Equatable, Sendable {
    var swipeThreshold: Double
    var springDamping: Double
    var heroCardLimit: Int
    var criticalUrgencyThreshold: Double

    enum CodingKeys: String, CodingKey {
        case swipeThreshold = "swipe_threshold"
        case springDamping = "spring_damping"
        case heroCardLimit = "hero_card_limit"
        case criticalUrgencyThreshold = "critical_urgency_threshold"
    }

    static let `default` = Phase3Config(
        swipeThreshold: 160,
        springDamping: 0.8,
        heroCardLimit: 1,
        criticalUrgencyThreshold: 0.8
    )

    init(
        swipeThreshold: Double = Phase3Config.default.swipeThreshold,
        springDamping: Double = Phase3Config.default.springDamping,
        heroCardLimit: Int = Phase3Config.default.heroCardLimit,
        criticalUrgencyThreshold: Double = Phase3Config.default.criticalUrgencyThreshold
    ) {
        self.swipeThreshold = min(max(swipeThreshold, 80), 280)
        self.springDamping = min(max(springDamping, 0.45), 0.95)
        self.heroCardLimit = min(max(heroCardLimit, 0), 3)
        self.criticalUrgencyThreshold = min(max(criticalUrgencyThreshold, 0.55), 0.95)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            swipeThreshold: try container.decodeIfPresent(Double.self, forKey: .swipeThreshold) ?? Self.default.swipeThreshold,
            springDamping: try container.decodeIfPresent(Double.self, forKey: .springDamping) ?? Self.default.springDamping,
            heroCardLimit: try container.decodeIfPresent(Int.self, forKey: .heroCardLimit) ?? Self.default.heroCardLimit,
            criticalUrgencyThreshold: try container.decodeIfPresent(Double.self, forKey: .criticalUrgencyThreshold) ??
                Self.default.criticalUrgencyThreshold
        )
    }
}

struct Phase4WalletConfig: Codable, Equatable, Sendable {
    var requiredDocuments: [WalletRequiredDocument]
    var biometricEnforced: Bool

    enum CodingKeys: String, CodingKey {
        case requiredDocuments = "required_docs"
        case biometricEnforced = "biometric_enforced"
    }

    static let `default` = Phase4WalletConfig(
        requiredDocuments: [.passport, .brp, .universityCAS],
        biometricEnforced: true
    )

    init(
        requiredDocuments: [WalletRequiredDocument] = Phase4WalletConfig.default.requiredDocuments,
        biometricEnforced: Bool = Phase4WalletConfig.default.biometricEnforced
    ) {
        let normalized = requiredDocuments.reduce(into: [WalletRequiredDocument]()) { partial, item in
            if !partial.contains(item) {
                partial.append(item)
            }
        }
        self.requiredDocuments = normalized.isEmpty ? Phase4WalletConfig.default.requiredDocuments : normalized
        self.biometricEnforced = biometricEnforced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawDocs = try container.decodeIfPresent([String].self, forKey: .requiredDocuments) ?? []
        let parsedDocs = rawDocs.compactMap(WalletRequiredDocument.fromRemoteValue(_:))
        self.init(
            requiredDocuments: parsedDocs.isEmpty ? Self.default.requiredDocuments : parsedDocs,
            biometricEnforced: try container.decodeIfPresent(Bool.self, forKey: .biometricEnforced) ?? Self.default.biometricEnforced
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requiredDocuments.map(\.rawValue), forKey: .requiredDocuments)
        try container.encode(biometricEnforced, forKey: .biometricEnforced)
    }
}

enum WalletRequiredDocument: String, Codable, CaseIterable, Hashable, Sendable {
    case passport
    case brp
    case universityCAS = "university_cas"
    case tenancy
    case ssn
    case sin
    case tfn
    case nationalID = "national_id"

    nonisolated var secureDocType: SecureDocType {
        switch self {
        case .passport:
            return .passport
        case .brp:
            return .studentVisa
        case .universityCAS:
            return .casLetter
        case .tenancy:
            return .tenancyAgreement
        case .ssn, .sin, .tfn, .nationalID:
            return .nationalID
        }
    }

    nonisolated static func fromRemoteValue(_ raw: String) -> WalletRequiredDocument? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "passport":
            return .passport
        case "brp", "student_visa", "visa":
            return .brp
        case "university_cas", "cas", "cas_letter":
            return .universityCAS
        case "tenancy", "tenancy_agreement":
            return .tenancy
        case "ssn", "social_security", "social_security_number":
            return .ssn
        case "sin", "social_insurance_number":
            return .sin
        case "tfn", "tax_file_number":
            return .tfn
        case "national_id", "identity_number", "id_number":
            return .nationalID
        default:
            return nil
        }
    }
}

struct Phase14MarketplaceConfig: Codable, Equatable, Sendable {
    var identityTokenTTLSeconds: Int
    var providers: [MarketplaceProviderDescriptor]

    enum CodingKeys: String, CodingKey {
        case identityTokenTTLSeconds = "identity_token_ttl_seconds"
        case providers
    }

    static let `default` = Phase14MarketplaceConfig(
        identityTokenTTLSeconds: 600,
        providers: []
    )

    init(
        identityTokenTTLSeconds: Int = Phase14MarketplaceConfig.default.identityTokenTTLSeconds,
        providers: [MarketplaceProviderDescriptor] = Phase14MarketplaceConfig.default.providers
    ) {
        self.identityTokenTTLSeconds = min(max(identityTokenTTLSeconds, 60), 3600)

        var deduplicated: [MarketplaceProviderDescriptor] = []
        var seenProviderIDs = Set<String>()
        for provider in providers {
            let normalized = provider.normalizedProviderID
            guard !normalized.isEmpty else { continue }
            guard seenProviderIDs.insert(normalized).inserted else { continue }
            deduplicated.append(provider)
        }
        self.providers = deduplicated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            identityTokenTTLSeconds: try container.decodeIfPresent(Int.self, forKey: .identityTokenTTLSeconds)
                ?? Phase14MarketplaceConfig.default.identityTokenTTLSeconds,
            providers: try container.decodeIfPresent([MarketplaceProviderDescriptor].self, forKey: .providers) ?? []
        )
    }
}

struct Phase15GlobalConfig: Codable, Equatable, Sendable {
    var activeRegion: ArrivalRegion
    var fallbackRegion: ArrivalRegion
    var regions: [RegionConfiguration]

    enum CodingKeys: String, CodingKey {
        case activeRegion = "active_region"
        case fallbackRegion = "fallback_region"
        case regions
    }

    static let `default` = Phase15GlobalConfig(
        activeRegion: .uk,
        fallbackRegion: .uk,
        regions: ArrivalRegion.allCases.map { RegionConfiguration.fallback(for: $0) }
    )

    init(
        activeRegion: ArrivalRegion = Phase15GlobalConfig.default.activeRegion,
        fallbackRegion: ArrivalRegion = Phase15GlobalConfig.default.fallbackRegion,
        regions: [RegionConfiguration] = Phase15GlobalConfig.default.regions
    ) {
        self.activeRegion = activeRegion
        self.fallbackRegion = fallbackRegion

        var deduplicated: [RegionConfiguration] = []
        var seen = Set<ArrivalRegion>()
        for regionConfig in regions {
            guard seen.insert(regionConfig.region).inserted else { continue }
            deduplicated.append(regionConfig)
        }

        self.regions = deduplicated.isEmpty ? Phase15GlobalConfig.default.regions : deduplicated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let activeRaw = try container.decodeIfPresent(String.self, forKey: .activeRegion) ?? ArrivalRegion.uk.rawValue
        let fallbackRaw = try container.decodeIfPresent(String.self, forKey: .fallbackRegion) ?? ArrivalRegion.uk.rawValue

        self.init(
            activeRegion: ArrivalRegion(remoteValue: activeRaw) ?? .uk,
            fallbackRegion: ArrivalRegion(remoteValue: fallbackRaw) ?? .uk,
            regions: try container.decodeIfPresent([RegionConfiguration].self, forKey: .regions) ?? []
        )
    }

    var regionRegistry: [ArrivalRegion: RegionConfiguration] {
        var registry = Dictionary(
            uniqueKeysWithValues: ArrivalRegion.allCases.map { region in
                (region, RegionConfiguration.fallback(for: region))
            }
        )

        for regionConfig in regions {
            registry[regionConfig.region] = regionConfig
        }

        return registry
    }
}

extension MarketplaceProviderDescriptor {
    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case displayName = "display_name"
        case serviceType = "service_type"
        case ctaTitle = "cta_title"
        case requiredDocs = "required_docs"
        case requestedFields = "requested_fields"
        case onboardingURL = "onboarding_url"
        case universalVerifyPath = "universal_verify_path"
        case completionTaskID = "completion_task_id"
        case completionCategoryID = "completion_category_id"
        case paymentMode = "payment_mode"
        case priceGBP = "price_gbp"
        case discoveryTag = "discovery_tag"
        case supportedRegions = "supported_regions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? ""
        let displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Provider"
        let serviceTypeRaw = try container.decodeIfPresent(String.self, forKey: .serviceType) ?? "unknown"
        let ctaTitle = try container.decodeIfPresent(String.self, forKey: .ctaTitle) ?? "Continue"
        let requiredDocsRaw = try container.decodeIfPresent([String].self, forKey: .requiredDocs) ?? []
        let requestedFieldsRaw = try container.decodeIfPresent([String].self, forKey: .requestedFields) ?? []
        let onboardingRaw = try container.decodeIfPresent(String.self, forKey: .onboardingURL)
        let universalVerifyPath = try container.decodeIfPresent(String.self, forKey: .universalVerifyPath)
        let completionTaskID = try container.decodeIfPresent(String.self, forKey: .completionTaskID)
        let completionCategoryID = try container.decodeIfPresent(String.self, forKey: .completionCategoryID)
        let paymentModeRaw = try container.decodeIfPresent(String.self, forKey: .paymentMode) ?? MarketplacePaymentMode.none.rawValue
        let priceGBP = try container.decodeIfPresent(Decimal.self, forKey: .priceGBP)
        let discoveryTag = try container.decodeIfPresent(String.self, forKey: .discoveryTag)
        let supportedRegionsRaw = try container.decodeIfPresent([String].self, forKey: .supportedRegions) ?? []

        let requiredDocs = requiredDocsRaw.compactMap(WalletRequiredDocument.fromRemoteValue(_:))
        let requestedFields = requestedFieldsRaw.compactMap { MarketplaceIdentityField(rawValue: $0) }
        let onboardingURL = onboardingRaw.flatMap { URL(string: $0) }
        let supportedRegions = supportedRegionsRaw.compactMap(ArrivalRegion.init(remoteValue:))

        self.init(
            providerID: providerID,
            displayName: displayName,
            serviceType: MarketplaceServiceType(rawValue: serviceTypeRaw),
            ctaTitle: ctaTitle,
            requiredDocs: requiredDocs,
            requestedFields: requestedFields,
            onboardingURL: onboardingURL,
            universalVerifyPath: universalVerifyPath,
            completionTaskID: completionTaskID,
            completionCategoryID: completionCategoryID,
            paymentMode: MarketplacePaymentMode(rawValue: paymentModeRaw) ?? .none,
            priceGBP: priceGBP,
            discoveryTag: discoveryTag,
            supportedRegions: supportedRegions
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerID, forKey: .providerID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(serviceType.rawValue, forKey: .serviceType)
        try container.encode(ctaTitle, forKey: .ctaTitle)
        try container.encode(requiredDocs.map(\.rawValue), forKey: .requiredDocs)
        try container.encode(requestedFields.map(\.rawValue), forKey: .requestedFields)
        try container.encodeIfPresent(onboardingURL?.absoluteString, forKey: .onboardingURL)
        try container.encodeIfPresent(universalVerifyPath, forKey: .universalVerifyPath)
        try container.encodeIfPresent(completionTaskID, forKey: .completionTaskID)
        try container.encodeIfPresent(completionCategoryID, forKey: .completionCategoryID)
        try container.encode(paymentMode.rawValue, forKey: .paymentMode)
        try container.encodeIfPresent(priceGBP, forKey: .priceGBP)
        try container.encodeIfPresent(discoveryTag, forKey: .discoveryTag)
        try container.encode(supportedRegions.map(\.rawValue), forKey: .supportedRegions)
    }
}
