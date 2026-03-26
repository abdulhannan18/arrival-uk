import Foundation

enum ArrivalRegion: String, Codable, CaseIterable, Hashable, Sendable {
    case uk
    case usa
    case canada
    case australia
    case global

    nonisolated init?(remoteValue: String) {
        let normalized = remoteValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "uk", "gb", "great_britain", "united_kingdom":
            self = .uk
        case "us", "usa", "united_states", "united_states_of_america":
            self = .usa
        case "ca", "canada":
            self = .canada
        case "au", "australia":
            self = .australia
        case "global", "default":
            self = .global
        default:
            return nil
        }
    }
}

enum RegionalComplianceProfile: String, Codable, CaseIterable, Sendable {
    case gdpr
    case ccpaCPRA = "ccpa_cpra"
    case pipl
    case global

    init(remoteValue: String) {
        let normalized = remoteValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch normalized {
        case "gdpr", "uk_gdpr", "eu_gdpr":
            self = .gdpr
        case "ccpa", "cpra", "ccpa_cpra":
            self = .ccpaCPRA
        case "pipl", "china_pipl":
            self = .pipl
        default:
            self = .global
        }
    }
}

enum RegionalConsentRequirement: String, Codable, CaseIterable, Sendable {
    case termsOfService = "terms_of_service"
    case privacyPolicy = "privacy_policy"
    case dataProcessing = "data_processing"
    case doNotSell = "do_not_sell"
    case dataResidencyNotice = "data_residency_notice"
    case financialDisclosure = "financial_disclosure"
}

enum HorizontalSwipeDirection: String, Codable, Sendable {
    case leftToRight = "left_to_right"
    case rightToLeft = "right_to_left"
}

struct RegionConfiguration: Codable, Equatable, Sendable {
    var region: ArrivalRegion
    var displayName: String
    var localeIdentifier: String
    var currencyCode: String
    var dateFormat: String
    var nationalIDLabel: String
    var apiBaseURL: URL
    var legalBaseURL: URL
    var identityRequirements: [WalletRequiredDocument]
    var survivalTaskBoostKeywords: [String]
    var complianceProfile: RegionalComplianceProfile
    var consentRequirements: [RegionalConsentRequirement]
    var semanticLocalization: [String: String]
    var assetLocalization: [String: String]
    var marketplaceProviderAllowList: [String]
    var heroCompletionSwipeDirection: HorizontalSwipeDirection?

    enum CodingKeys: String, CodingKey {
        case region
        case displayName = "display_name"
        case localeIdentifier = "locale_identifier"
        case currencyCode = "currency_code"
        case dateFormat = "date_format"
        case nationalIDLabel = "national_id_label"
        case apiBaseURL = "api_base_url"
        case legalBaseURL = "legal_base_url"
        case identityRequirements = "identity_requirements"
        case survivalTaskBoostKeywords = "survival_task_boost_keywords"
        case complianceProfile = "compliance_profile"
        case consentRequirements = "consent_requirements"
        case semanticLocalization = "semantic_localization"
        case assetLocalization = "asset_localization"
        case marketplaceProviderAllowList = "marketplace_provider_allow_list"
        case heroCompletionSwipeDirection = "hero_completion_swipe_direction"
    }

    init(
        region: ArrivalRegion,
        displayName: String,
        localeIdentifier: String,
        currencyCode: String,
        dateFormat: String,
        nationalIDLabel: String,
        apiBaseURL: URL,
        legalBaseURL: URL,
        identityRequirements: [WalletRequiredDocument],
        survivalTaskBoostKeywords: [String],
        complianceProfile: RegionalComplianceProfile,
        consentRequirements: [RegionalConsentRequirement],
        semanticLocalization: [String: String],
        assetLocalization: [String: String],
        marketplaceProviderAllowList: [String],
        heroCompletionSwipeDirection: HorizontalSwipeDirection? = nil
    ) {
        self.region = region
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Global"
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.localeIdentifier = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "en_GB"
            : localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "GBP"
            : currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.dateFormat = dateFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "dd MMM yyyy"
            : dateFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nationalIDLabel = nationalIDLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "National ID"
            : nationalIDLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiBaseURL = Self.normalizedHTTPSURL(
            apiBaseURL,
            fallback: Self.fallbackAPIBaseURL(for: region)
        )
        self.legalBaseURL = Self.normalizedHTTPSURL(
            legalBaseURL,
            fallback: Self.fallbackLegalBaseURL(for: region)
        )

        let deduplicatedIdentity = Self.deduplicated(identityRequirements)
        self.identityRequirements = deduplicatedIdentity.isEmpty
            ? Self.fallbackIdentityRequirements(for: region)
            : deduplicatedIdentity

        self.survivalTaskBoostKeywords = Self.normalizedKeywords(survivalTaskBoostKeywords)
        self.complianceProfile = complianceProfile

        let deduplicatedConsents = Self.deduplicated(consentRequirements)
        self.consentRequirements = deduplicatedConsents.isEmpty
            ? Self.fallbackConsentRequirements(for: region)
            : deduplicatedConsents

        self.semanticLocalization = Self.normalizedDictionary(semanticLocalization)
        self.assetLocalization = Self.normalizedDictionary(assetLocalization)

        self.marketplaceProviderAllowList = marketplaceProviderAllowList
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { partial, value in
                if !partial.contains(value) {
                    partial.append(value)
                }
            }

        self.heroCompletionSwipeDirection = heroCompletionSwipeDirection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let regionRaw = try container.decodeIfPresent(String.self, forKey: .region) ?? ArrivalRegion.uk.rawValue
        let resolvedRegion = ArrivalRegion(remoteValue: regionRaw) ?? .uk

        let complianceRaw = try container.decodeIfPresent(String.self, forKey: .complianceProfile)
            ?? RegionalComplianceProfile.global.rawValue
        let consentRaw = try container.decodeIfPresent([String].self, forKey: .consentRequirements) ?? []
        let identityRaw = try container.decodeIfPresent([String].self, forKey: .identityRequirements) ?? []

        self.init(
            region: resolvedRegion,
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName)
                ?? Self.fallback(for: resolvedRegion).displayName,
            localeIdentifier: try container.decodeIfPresent(String.self, forKey: .localeIdentifier)
                ?? Self.fallback(for: resolvedRegion).localeIdentifier,
            currencyCode: try container.decodeIfPresent(String.self, forKey: .currencyCode)
                ?? Self.fallback(for: resolvedRegion).currencyCode,
            dateFormat: try container.decodeIfPresent(String.self, forKey: .dateFormat)
                ?? Self.fallback(for: resolvedRegion).dateFormat,
            nationalIDLabel: try container.decodeIfPresent(String.self, forKey: .nationalIDLabel)
                ?? Self.fallback(for: resolvedRegion).nationalIDLabel,
            apiBaseURL: (try container.decodeIfPresent(URL.self, forKey: .apiBaseURL))
                ?? Self.fallback(for: resolvedRegion).apiBaseURL,
            legalBaseURL: (try container.decodeIfPresent(URL.self, forKey: .legalBaseURL))
                ?? Self.fallback(for: resolvedRegion).legalBaseURL,
            identityRequirements: identityRaw.compactMap(WalletRequiredDocument.fromRemoteValue(_:)),
            survivalTaskBoostKeywords: try container.decodeIfPresent([String].self, forKey: .survivalTaskBoostKeywords) ?? [],
            complianceProfile: RegionalComplianceProfile(remoteValue: complianceRaw),
            consentRequirements: consentRaw.compactMap(RegionalConsentRequirement.init(rawValue:)),
            semanticLocalization: try container.decodeIfPresent([String: String].self, forKey: .semanticLocalization) ?? [:],
            assetLocalization: try container.decodeIfPresent([String: String].self, forKey: .assetLocalization) ?? [:],
            marketplaceProviderAllowList: try container.decodeIfPresent([String].self, forKey: .marketplaceProviderAllowList) ?? [],
            heroCompletionSwipeDirection: try container.decodeIfPresent(
                HorizontalSwipeDirection.self,
                forKey: .heroCompletionSwipeDirection
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(region.rawValue, forKey: .region)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(localeIdentifier, forKey: .localeIdentifier)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(dateFormat, forKey: .dateFormat)
        try container.encode(nationalIDLabel, forKey: .nationalIDLabel)
        try container.encode(apiBaseURL, forKey: .apiBaseURL)
        try container.encode(legalBaseURL, forKey: .legalBaseURL)
        try container.encode(identityRequirements.map(\.rawValue), forKey: .identityRequirements)
        try container.encode(survivalTaskBoostKeywords, forKey: .survivalTaskBoostKeywords)
        try container.encode(complianceProfile.rawValue, forKey: .complianceProfile)
        try container.encode(consentRequirements.map(\.rawValue), forKey: .consentRequirements)
        try container.encode(semanticLocalization, forKey: .semanticLocalization)
        try container.encode(assetLocalization, forKey: .assetLocalization)
        try container.encode(marketplaceProviderAllowList, forKey: .marketplaceProviderAllowList)
        try container.encodeIfPresent(heroCompletionSwipeDirection, forKey: .heroCompletionSwipeDirection)
    }

    static func fallback(for region: ArrivalRegion) -> RegionConfiguration {
        switch region {
        case .uk:
            return RegionConfiguration(
                region: .uk,
                displayName: "United Kingdom",
                localeIdentifier: "en_GB",
                currencyCode: "GBP",
                dateFormat: "dd MMM yyyy",
                nationalIDLabel: "National Insurance Number",
                apiBaseURL: requiredStaticURL("https://api.uk.arrival.com"),
                legalBaseURL: requiredStaticURL("https://uk.arrival.com"),
                identityRequirements: [.passport, .brp, .universityCAS],
                survivalTaskBoostKeywords: ["gp", "nhs", "brp", "bank account"],
                complianceProfile: .gdpr,
                consentRequirements: [.termsOfService, .privacyPolicy, .dataProcessing, .financialDisclosure],
                semanticLocalization: [:],
                assetLocalization: [:],
                marketplaceProviderAllowList: []
            )
        case .usa:
            return RegionConfiguration(
                region: .usa,
                displayName: "United States",
                localeIdentifier: "en_US",
                currencyCode: "USD",
                dateFormat: "MMM d, yyyy",
                nationalIDLabel: "Social Security Number",
                apiBaseURL: requiredStaticURL("https://api.us.arrival.com"),
                legalBaseURL: requiredStaticURL("https://us.arrival.com"),
                identityRequirements: [.passport, .ssn, .tenancy],
                survivalTaskBoostKeywords: ["health insurance", "ssn", "social security", "bank account"],
                complianceProfile: .ccpaCPRA,
                consentRequirements: [.termsOfService, .privacyPolicy, .doNotSell, .financialDisclosure],
                semanticLocalization: [
                    "flat": "apartment",
                    "chemist": "pharmacy",
                    "tube": "subway",
                    "gp": "primary care doctor",
                    "post office": "US Mail"
                ],
                assetLocalization: ["post_office": "mailbox"],
                marketplaceProviderAllowList: []
            )
        case .canada:
            return RegionConfiguration(
                region: .canada,
                displayName: "Canada",
                localeIdentifier: "en_CA",
                currencyCode: "CAD",
                dateFormat: "yyyy-MM-dd",
                nationalIDLabel: "Social Insurance Number",
                apiBaseURL: requiredStaticURL("https://api.ca.arrival.com"),
                legalBaseURL: requiredStaticURL("https://ca.arrival.com"),
                identityRequirements: [.passport, .sin, .tenancy],
                survivalTaskBoostKeywords: ["health insurance", "sin", "bank account"],
                complianceProfile: .gdpr,
                consentRequirements: [.termsOfService, .privacyPolicy, .dataProcessing],
                semanticLocalization: [
                    "flat": "apartment",
                    "chemist": "pharmacy",
                    "tube": "subway",
                    "gp": "family doctor",
                    "post office": "Canada Post"
                ],
                assetLocalization: ["post_office": "mailbox"],
                marketplaceProviderAllowList: []
            )
        case .australia:
            return RegionConfiguration(
                region: .australia,
                displayName: "Australia",
                localeIdentifier: "en_AU",
                currencyCode: "AUD",
                dateFormat: "d MMM yyyy",
                nationalIDLabel: "Tax File Number",
                apiBaseURL: requiredStaticURL("https://api.au.arrival.com"),
                legalBaseURL: requiredStaticURL("https://au.arrival.com"),
                identityRequirements: [.passport, .tfn, .tenancy],
                survivalTaskBoostKeywords: ["medicare", "tfn", "health insurance", "bank account"],
                complianceProfile: .global,
                consentRequirements: [.termsOfService, .privacyPolicy, .financialDisclosure],
                semanticLocalization: [
                    "flat": "apartment",
                    "chemist": "pharmacy",
                    "tube": "train",
                    "post office": "Australia Post"
                ],
                assetLocalization: ["post_office": "mailbox"],
                marketplaceProviderAllowList: []
            )
        case .global:
            return RegionConfiguration(
                region: .global,
                displayName: "Global",
                localeIdentifier: "en_GB",
                currencyCode: "GBP",
                dateFormat: "dd MMM yyyy",
                nationalIDLabel: "National ID",
                apiBaseURL: requiredStaticURL("https://api.global.arrival.com"),
                legalBaseURL: requiredStaticURL("https://global.arrival.com"),
                identityRequirements: [.passport],
                survivalTaskBoostKeywords: [],
                complianceProfile: .global,
                consentRequirements: [.termsOfService, .privacyPolicy],
                semanticLocalization: [:],
                assetLocalization: [:],
                marketplaceProviderAllowList: []
            )
        }
    }

    private static func normalizedHTTPSURL(_ value: URL, fallback: URL) -> URL {
        guard value.scheme?.lowercased() == "https" else { return fallback }
        return value
    }

    private static func requiredStaticURL(_ value: String) -> URL {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https" else {
            preconditionFailure("Invalid static HTTPS URL: \(value)")
        }
        return url
    }

    private static func fallbackAPIBaseURL(for region: ArrivalRegion) -> URL {
        switch region {
        case .uk:
            return requiredStaticURL("https://api.uk.arrival.com")
        case .usa:
            return requiredStaticURL("https://api.us.arrival.com")
        case .canada:
            return requiredStaticURL("https://api.ca.arrival.com")
        case .australia:
            return requiredStaticURL("https://api.au.arrival.com")
        case .global:
            return requiredStaticURL("https://api.global.arrival.com")
        }
    }

    private static func fallbackLegalBaseURL(for region: ArrivalRegion) -> URL {
        switch region {
        case .uk:
            return requiredStaticURL("https://uk.arrival.com")
        case .usa:
            return requiredStaticURL("https://us.arrival.com")
        case .canada:
            return requiredStaticURL("https://ca.arrival.com")
        case .australia:
            return requiredStaticURL("https://au.arrival.com")
        case .global:
            return requiredStaticURL("https://global.arrival.com")
        }
    }

    private static func fallbackIdentityRequirements(for region: ArrivalRegion) -> [WalletRequiredDocument] {
        switch region {
        case .uk:
            return [.passport, .brp, .universityCAS]
        case .usa:
            return [.passport, .ssn, .tenancy]
        case .canada:
            return [.passport, .sin, .tenancy]
        case .australia:
            return [.passport, .tfn, .tenancy]
        case .global:
            return [.passport]
        }
    }

    private static func fallbackConsentRequirements(for region: ArrivalRegion) -> [RegionalConsentRequirement] {
        switch region {
        case .uk:
            return [.termsOfService, .privacyPolicy, .dataProcessing, .financialDisclosure]
        case .usa:
            return [.termsOfService, .privacyPolicy, .doNotSell, .financialDisclosure]
        case .canada:
            return [.termsOfService, .privacyPolicy, .dataProcessing]
        case .australia:
            return [.termsOfService, .privacyPolicy, .financialDisclosure]
        case .global:
            return [.termsOfService, .privacyPolicy]
        }
    }

    private static func deduplicated<T: Hashable>(_ values: [T]) -> [T] {
        values.reduce(into: [T]()) { partial, value in
            if !partial.contains(value) {
                partial.append(value)
            }
        }
    }

    private static func normalizedKeywords(_ values: [String]) -> [String] {
        values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        .filter { !$0.isEmpty }
        .reduce(into: [String]()) { partial, value in
            if !partial.contains(value) {
                partial.append(value)
            }
        }
    }

    private static func normalizedDictionary(_ value: [String: String]) -> [String: String] {
        value.reduce(into: [String: String]()) { partial, entry in
            let source = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let target = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !target.isEmpty else { return }
            partial[source] = target
        }
    }
}

enum RegionRuntime {
    private static let defaults = UserDefaults.standard
    private static let registryKey = StorageKey.phase15RegionRegistry.rawValue
    private static let activeRegionKey = StorageKey.phase15ActiveRegion.rawValue

    static var activeRegion: ArrivalRegion {
        if let raw = defaults.string(forKey: activeRegionKey),
           let parsed = ArrivalRegion(remoteValue: raw) {
            return parsed
        }
        return inferredRegionFromLocale()
    }

    static var activeConfiguration: RegionConfiguration {
        let registry = registryByRegion()
        if let resolved = registry[activeRegion] {
            return resolved
        }
        return registry[.uk] ?? RegionConfiguration.fallback(for: .uk)
    }

    static var locale: Locale {
        Locale(identifier: activeConfiguration.localeIdentifier)
    }

    static var apiBaseURL: URL {
        activeConfiguration.apiBaseURL
    }

    static var legalBaseURL: URL {
        activeConfiguration.legalBaseURL
    }

    static var complianceProfile: RegionalComplianceProfile {
        activeConfiguration.complianceProfile
    }

    static var consentRequirements: [RegionalConsentRequirement] {
        activeConfiguration.consentRequirements
    }

    static var isRightToLeftLanguage: Bool {
        let languageCode = locale.language.languageCode?.identifier
            ?? Locale.autoupdatingCurrent.language.languageCode?.identifier
            ?? "en"
        return NSLocale.characterDirection(forLanguage: languageCode) == .rightToLeft
    }

    static func completionSwipeDirection(forLayoutDirectionRTL isLayoutDirectionRTL: Bool) -> HorizontalSwipeDirection {
        if let override = activeConfiguration.heroCompletionSwipeDirection {
            return override
        }
        return isLayoutDirectionRTL ? .leftToRight : .rightToLeft
    }

    static func semanticLocalized(_ text: String) -> String {
        let mappings = activeConfiguration.semanticLocalization
        guard !mappings.isEmpty else { return text }

        var output = text
        for source in mappings.keys.sorted(by: { $0.count > $1.count }) {
            guard let replacement = mappings[source] else { continue }
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: source))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return output
    }

    static func localizedAssetName(for key: String, fallback: String) -> String {
        let normalizedKey = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalizedKey.isEmpty else { return fallback }
        return activeConfiguration.assetLocalization[normalizedKey] ?? fallback
    }

    static func apply(phase15 config: Phase15GlobalConfig) {
        let merged = mergedRegistry(with: config.regions)
        persistRegistry(Array(merged.values))

        let resolvedRegion: ArrivalRegion = {
            if merged[config.activeRegion] != nil {
                return config.activeRegion
            }
            if merged[config.fallbackRegion] != nil {
                return config.fallbackRegion
            }
            return inferredRegionFromLocale()
        }()

        defaults.set(resolvedRegion.rawValue, forKey: activeRegionKey)
    }

    static func setActiveRegion(_ region: ArrivalRegion) {
        defaults.set(region.rawValue, forKey: activeRegionKey)
    }

    static func filterMarketplaceProviders(
        _ providers: [MarketplaceProviderDescriptor]
    ) -> [MarketplaceProviderDescriptor] {
        let allowList = activeConfiguration.marketplaceProviderAllowList

        let regionFiltered = providers.filter { provider in
            provider.supports(region: activeRegion)
        }

        guard !allowList.isEmpty else { return regionFiltered }
        let allowed = Set(allowList)
        return regionFiltered.filter { allowed.contains($0.normalizedProviderID) }
    }

    private static func registryByRegion() -> [ArrivalRegion: RegionConfiguration] {
        if let persistedData = defaults.data(forKey: registryKey),
           let persisted = try? JSONDecoder().decode([RegionConfiguration].self, from: persistedData),
           !persisted.isEmpty {
            return mergedRegistry(with: persisted)
        }
        return mergedRegistry(with: [])
    }

    private static func mergedRegistry(with remote: [RegionConfiguration]) -> [ArrivalRegion: RegionConfiguration] {
        var registry = Dictionary(
            uniqueKeysWithValues: ArrivalRegion.allCases.map { region in
                (region, RegionConfiguration.fallback(for: region))
            }
        )
        for entry in remote {
            registry[entry.region] = entry
        }
        return registry
    }

    private static func persistRegistry(_ registry: [RegionConfiguration]) {
        guard let encoded = try? JSONEncoder().encode(registry) else { return }
        defaults.set(encoded, forKey: registryKey)
    }

    private static func inferredRegionFromLocale() -> ArrivalRegion {
        let countryCode = Locale.autoupdatingCurrent.region?.identifier.lowercased() ?? "gb"
        switch countryCode {
        case "gb", "uk":
            return .uk
        case "us":
            return .usa
        case "ca":
            return .canada
        case "au":
            return .australia
        default:
            return .uk
        }
    }
}

extension MarketplaceProviderDescriptor {
    func supports(region: ArrivalRegion) -> Bool {
        guard !supportedRegions.isEmpty else { return true }
        return supportedRegions.contains(region) || supportedRegions.contains(.global)
    }
}
