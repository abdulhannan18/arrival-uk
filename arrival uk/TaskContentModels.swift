import Foundation

enum TaskContentType: String, Codable, Hashable {
    case richGuide = "rich-guide"
    case comparisonGuide = "comparison-guide"
    case processGuide = "process-guide"
    case simpleText = "simple-text"
}

enum SmartDataKey: String, Codable, Hashable, CaseIterable {
    case passportNumber = "passportNumber"
    case ukAddress = "ukAddress"
    case universityCAS = "universityCAS"
    case arrivalDate = "arrivalDate"
    case city = "city"
    case university = "university"
    case studentEmail = "studentEmail"
    case studentName = "studentName"
}

struct CheckItem: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var isOn: Bool

    init(id: String = UUID().uuidString, title: String, isOn: Bool = false) {
        self.id = id
        self.title = title
        self.isOn = isOn
    }
}

struct TaskDetailContent: Hashable, Codable {
    var heroGradient: [String]
    var heroIcon: String
    var estimatedTime: Int
    var requiredData: [SmartDataKey]
    var preFlightChecks: [CheckItem]
    var actionURL: String?
    var actionLabel: String?

    init(
        heroGradient: [String] = [
            ArrivalColor.hex(family: .institutionalBlue, toneIndex: 6),
            ArrivalColor.hex(family: .careerImperial, toneIndex: 8),
        ],
        heroIcon: String = "checklist",
        estimatedTime: Int = 15,
        requiredData: [SmartDataKey] = [],
        preFlightChecks: [CheckItem] = [],
        actionURL: String? = nil,
        actionLabel: String? = nil
    ) {
        self.heroGradient = heroGradient
        self.heroIcon = heroIcon
        self.estimatedTime = estimatedTime
        self.requiredData = requiredData
        self.preFlightChecks = preFlightChecks
        self.actionURL = actionURL
        self.actionLabel = actionLabel
    }

    private enum CodingKeys: String, CodingKey {
        case heroGradient
        case heroIcon
        case estimatedTime
        case requiredData
        case preFlightChecks
        case actionURL
        case actionLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.heroGradient = try container.decodeIfPresent([String].self, forKey: .heroGradient) ?? [
            ArrivalColor.hex(family: .institutionalBlue, toneIndex: 6),
            ArrivalColor.hex(family: .careerImperial, toneIndex: 8),
        ]
        self.heroIcon = try container.decodeIfPresent(String.self, forKey: .heroIcon) ?? "checklist"
        self.estimatedTime = max(1, try container.decodeIfPresent(Int.self, forKey: .estimatedTime) ?? 15)
        self.requiredData = try container.decodeIfPresent([SmartDataKey].self, forKey: .requiredData) ?? []
        self.preFlightChecks = try container.decodeIfPresent([CheckItem].self, forKey: .preFlightChecks) ?? []
        self.actionURL = try container.decodeIfPresent(String.self, forKey: .actionURL)
        self.actionLabel = try container.decodeIfPresent(String.self, forKey: .actionLabel)
    }
}

struct TaskGuideContent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let categoryTheme: TaskGuideTheme
    let timeEstimate: String
    let urgencyTag: String
    let insightFragments: [String]
    let readingBody: String
    let instructions: [TaskGuideInstruction]
    let officialURL: URL?
    let actionButtonTitle: String
}

struct TaskGuideInstruction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
}

enum TaskGuideTheme: String, Hashable, Codable {
    case health
    case money
    case academic

    var gradientHex: [String] {
        switch self {
        case .health:
            return [
                ArrivalColor.hex(family: .medicalEmerald, toneIndex: 9),
                ArrivalColor.hex(family: .communityCopper, toneIndex: 14),
            ]
        case .money:
            return [
                ArrivalColor.hex(family: .financialMidnight, toneIndex: 8),
                ArrivalColor.hex(family: .careerImperial, toneIndex: 12),
            ]
        case .academic:
            return [
                ArrivalColor.hex(family: .institutionalBlue, toneIndex: 7),
                ArrivalColor.hex(family: .mobilityAmber, toneIndex: 12),
            ]
        }
    }
}

struct TaskContent: Hashable, Codable {
    var type: TaskContentType
    var sections: [ContentSection]

    init(type: TaskContentType = .simpleText, sections: [ContentSection] = []) {
        self.type = type
        self.sections = sections
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(TaskContentType.self, forKey: .type) ?? .simpleText
        self.sections = try container.decodeIfPresent([ContentSection].self, forKey: .sections) ?? []
    }
}

enum ContentSection: Hashable, Codable {
    case why(WhySectionData)
    case overview(OverviewSectionData)
    case checklist(ChecklistSectionData)
    case options(OptionsSectionData)
    case comparisonTable(OptionsSectionData)
    case tips(TipsSectionData)
    case references(ReferencesSectionData)
    case officialReferences(OfficialReferencesSectionData)
    case steps(StepsSectionData)
    case apps(AppsSectionData)
    case faqs(FAQSectionData)
    case unsupported(UnsupportedSectionData)

    private enum TypeKey: String, CodingKey {
        case type
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let typeRaw = try container.decode(String.self, forKey: .type)

        switch typeRaw {
        case "why":
            self = .why(try WhySectionData(from: decoder))
        case "overview":
            self = .overview(try OverviewSectionData(from: decoder))
        case "checklist":
            self = .checklist(try ChecklistSectionData(from: decoder))
        case "options":
            self = .options(try OptionsSectionData(from: decoder))
        case "comparison-table":
            self = .comparisonTable(try OptionsSectionData(from: decoder))
        case "tips":
            self = .tips(try TipsSectionData(from: decoder))
        case "references":
            self = .references(try ReferencesSectionData(from: decoder))
        case "official-references":
            self = .officialReferences(try OfficialReferencesSectionData(from: decoder))
        case "steps":
            self = .steps(try StepsSectionData(from: decoder))
        case "apps":
            self = .apps(try AppsSectionData(from: decoder))
        case "faqs":
            self = .faqs(try FAQSectionData(from: decoder))
        default:
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let rawPayload = try? JSONValue(from: decoder)
            self = .unsupported(
                UnsupportedSectionData(
                    type: typeRaw,
                    title: title,
                    payload: UnsupportedSectionData.extractPayload(from: rawPayload)
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .why(let value):
            try value.encode(to: encoder)
        case .overview(let value):
            try value.encode(to: encoder)
        case .checklist(let value):
            try value.encode(to: encoder)
        case .options(let value):
            try value.encode(to: encoder)
        case .comparisonTable(let value):
            var adapted = value
            adapted.type = "comparison-table"
            try adapted.encode(to: encoder)
        case .tips(let value):
            try value.encode(to: encoder)
        case .references(let value):
            try value.encode(to: encoder)
        case .officialReferences(let value):
            try value.encode(to: encoder)
        case .steps(let value):
            try value.encode(to: encoder)
        case .apps(let value):
            try value.encode(to: encoder)
        case .faqs(let value):
            try value.encode(to: encoder)
        case .unsupported(let value):
            try value.encode(to: encoder)
        }
    }
}

struct WhySectionData: Hashable, Codable {
    var type: String = "why"
    var title: String?
    var description: String?
    var content: String
    var icon: String?
}

struct OverviewSectionData: Hashable, Codable {
    var type: String = "overview"
    var title: String?
    var description: String?
    var content: String
}

struct ChecklistSectionData: Hashable, Codable {
    var type: String = "checklist"
    var title: String?
    var description: String?
    var items: [String]
    var allowUserChecks: Bool?
}

struct OptionsSectionData: Hashable, Codable {
    var type: String = "options"
    var title: String?
    var description: String?
    var items: [OptionItem]
}

enum SourceTrustType: String, Codable, Hashable {
    case official
    case university
    case partner
    case community
    case editorial
    case unknown

    var label: String {
        switch self {
        case .official:
            return "Official"
        case .university:
            return "University"
        case .partner:
            return "Partner"
        case .community:
            return "Community"
        case .editorial:
            return "Editorial"
        case .unknown:
            return "Unverified"
        }
    }
}

struct AudienceFilters: Hashable, Codable {
    var cities: [String] = []
    var universities: [String] = []

    var isEmpty: Bool {
        cities.isEmpty && universities.isEmpty
    }

    func matches(city: String, university: String) -> Bool {
        let normalizedCity = Self.normalize(city)
        let normalizedUniversity = Self.normalize(university)

        let cityMatch: Bool
        if cities.isEmpty || normalizedCity.isEmpty {
            cityMatch = true
        } else {
            cityMatch = cities.contains { Self.matchesFilter($0, query: normalizedCity) }
        }

        let universityMatch: Bool
        if universities.isEmpty || normalizedUniversity.isEmpty {
            universityMatch = true
        } else {
            universityMatch = universities.contains { Self.matchesFilter($0, query: normalizedUniversity) }
        }

        return cityMatch && universityMatch
    }

    private static func matchesFilter(_ rawFilter: String, query: String) -> Bool {
        let filter = normalize(rawFilter)
        guard !filter.isEmpty else { return true }
        if filter == "*" || filter == "all" {
            return true
        }
        return query.contains(filter) || filter.contains(query)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

struct SourceMetadata: Hashable, Codable {
    var sourceType: SourceTrustType?
    var sourceName: String?
    var lastVerified: String?
    var audience: AudienceFilters?
    var note: String?

    var resolvedTrustType: SourceTrustType {
        sourceType ?? .unknown
    }

    var verifiedLabel: String? {
        guard let lastVerified, !lastVerified.isEmpty else { return nil }
        if let date = Self.isoFormatter.date(from: lastVerified) ?? Self.fallbackFormatter.date(from: lastVerified) {
            return Self.outputFormatter.string(from: date)
        }
        return lastVerified
    }

    func matchesAudience(city: String, university: String) -> Bool {
        guard let audience else { return true }
        return audience.matches(city: city, university: university)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct OptionItem: Hashable, Codable {
    var name: String
    var description: String?
    var rating: Double?
    var tags: [String] = []
    var priceLevel: String?
    var link: LinkData?
    var location: LocationData?
    var highlights: [String] = []
    var source: SourceMetadata?
    var audience: AudienceFilters?

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case rating
        case tags
        case priceLevel
        case link
        case location
        case highlights
        case source
        case audience
    }

    init(
        name: String,
        description: String? = nil,
        rating: Double? = nil,
        tags: [String] = [],
        priceLevel: String? = nil,
        link: LinkData? = nil,
        location: LocationData? = nil,
        highlights: [String] = [],
        source: SourceMetadata? = nil,
        audience: AudienceFilters? = nil
    ) {
        self.name = name
        self.description = description
        self.rating = rating
        self.tags = tags
        self.priceLevel = priceLevel
        self.link = link
        self.location = location
        self.highlights = highlights
        self.source = source
        self.audience = audience
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.priceLevel = try container.decodeIfPresent(String.self, forKey: .priceLevel)
        self.link = try container.decodeIfPresent(LinkData.self, forKey: .link)
        self.location = try container.decodeIfPresent(LocationData.self, forKey: .location)
        self.highlights = try container.decodeIfPresent([String].self, forKey: .highlights) ?? []
        self.source = try container.decodeIfPresent(SourceMetadata.self, forKey: .source)
        self.audience = try container.decodeIfPresent(AudienceFilters.self, forKey: .audience)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(priceLevel, forKey: .priceLevel)
        try container.encodeIfPresent(link, forKey: .link)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(highlights, forKey: .highlights)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(audience, forKey: .audience)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct TipsSectionData: Hashable, Codable {
    var type: String = "tips"
    var title: String?
    var description: String?
    var items: [TipItem]
}

struct TipItem: Hashable, Codable {
    var text: String
    var author: String?
    var upvotes: Int?
}

struct ReferencesSectionData: Hashable, Codable {
    var type: String = "references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

struct OfficialReferencesSectionData: Hashable, Codable {
    var type: String = "official-references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

struct ReferenceItem: Hashable, Codable {
    var title: String
    var description: String?
    var url: String
    var type: String?
    var icon: String?
    var organization: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedSourceMetadata: SourceMetadata? {
        if let source {
            return source
        }

        if let type, type.lowercased() == "official" {
            return SourceMetadata(
                sourceType: .official,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        if let organization, !organization.isEmpty {
            return SourceMetadata(
                sourceType: .editorial,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        return nil
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = resolvedSourceMetadata?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct StepsSectionData: Hashable, Codable {
    var type: String = "steps"
    var title: String?
    var description: String?
    var items: [ProcessStepItem]
}

struct ProcessStepItem: Hashable, Codable {
    var number: Int
    var title: String
    var duration: String?
    var cost: String?
    var description: String?
    var actions: [StepAction] = []
    var requirements: [String] = []
    var tips: [String] = []

    private enum CodingKeys: String, CodingKey {
        case number
        case title
        case duration
        case cost
        case description
        case actions
        case requirements
        case tips
    }

    init(
        number: Int,
        title: String,
        duration: String? = nil,
        cost: String? = nil,
        description: String? = nil,
        actions: [StepAction] = [],
        requirements: [String] = [],
        tips: [String] = []
    ) {
        self.number = number
        self.title = title
        self.duration = duration
        self.cost = cost
        self.description = description
        self.actions = actions
        self.requirements = requirements
        self.tips = tips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try container.decode(Int.self, forKey: .number)
        self.title = try container.decode(String.self, forKey: .title)
        self.duration = try container.decodeIfPresent(String.self, forKey: .duration)
        self.cost = try container.decodeIfPresent(String.self, forKey: .cost)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.actions = try container.decodeIfPresent([StepAction].self, forKey: .actions) ?? []
        self.requirements = try container.decodeIfPresent([String].self, forKey: .requirements) ?? []
        self.tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(cost, forKey: .cost)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(actions, forKey: .actions)
        try container.encode(requirements, forKey: .requirements)
        try container.encode(tips, forKey: .tips)
    }
}

struct StepAction: Hashable, Codable {
    var type: String
    var label: String
    var url: String?
    var icon: String?
    var name: String?
    var cost: String?
    var searchTerm: String?
    var source: SourceMetadata?

    var resolvedURL: URL? {
        if let url, let parsed = URL(string: url) {
            return parsed
        }

        if let searchTerm, !searchTerm.isEmpty {
            let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

struct AppsSectionData: Hashable, Codable {
    var type: String = "apps"
    var title: String?
    var description: String?
    var items: [AppRecommendationItem]
}

struct AppRecommendationItem: Hashable, Codable {
    var name: String
    var description: String?
    var icon: String?
    var downloadLinks: AppDownloadLinks?
}

struct AppDownloadLinks: Hashable, Codable {
    var ios: String?
    var android: String?

    var iosURL: URL? {
        guard let ios, !ios.isEmpty else { return nil }
        return URL(string: ios)
    }

    var androidURL: URL? {
        guard let android, !android.isEmpty else { return nil }
        return URL(string: android)
    }

    var primaryURL: URL? {
        iosURL ?? androidURL
    }
}

struct FAQSectionData: Hashable, Codable {
    var type: String = "faqs"
    var title: String?
    var description: String?
    var items: [FAQItem]
}

struct FAQItem: Hashable, Codable {
    var question: String
    var answer: String
}

struct LinkData: Hashable, Codable {
    var type: String
    var url: String
    var label: String?
    var tracking: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedURL: URL? {
        URL(string: url)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

struct LocationData: Hashable, Codable {
    var type: String
    var search: String?
    var coordinates: Coordinates?
    var address: String?

    struct Coordinates: Hashable, Codable {
        var lat: Double
        var lng: Double
    }

    var mapsURL: URL? {
        if let search, !search.isEmpty {
            let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        if let coordinates {
            return URL(string: "https://maps.apple.com/?ll=\(coordinates.lat),\(coordinates.lng)")
        }

        if let address, !address.isEmpty {
            let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

enum JSONValue: Hashable, Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: JSONValue] = [:]
            for key in keyedContainer.allKeys {
                object[key.stringValue] = try keyedContainer.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !unkeyedContainer.isAtEnd {
                array.append(try unkeyedContainer.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        let singleContainer = try decoder.singleValueContainer()
        if singleContainer.decodeNil() {
            self = .null
        } else if let boolValue = try? singleContainer.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? singleContainer.decode(Double.self) {
            self = .number(numberValue)
        } else if let stringValue = try? singleContainer.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: singleContainer,
                debugDescription: "Unsupported JSON payload"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let value):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, payload) in value {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try container.encode(payload, forKey: codingKey)
            }
        case .array(let value):
            var container = encoder.unkeyedContainer()
            for payload in value {
                try container.encode(payload)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

struct UnsupportedSectionData: Hashable, Codable {
    var type: String
    var title: String?
    var payload: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case type
        case title
    }

    init(type: String, title: String?, payload: JSONValue? = nil) {
        self.type = type
        self.title = title
        self.payload = payload
    }

    static func extractPayload(from rawValue: JSONValue?) -> JSONValue? {
        guard case .object(let rawObject) = rawValue else { return nil }
        var filtered = rawObject
        filtered.removeValue(forKey: "type")
        filtered.removeValue(forKey: "title")
        return filtered.isEmpty ? nil : .object(filtered)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        let rawPayload = try? JSONValue(from: decoder)
        self.payload = Self.extractPayload(from: rawPayload)
    }

    func encode(to encoder: Encoder) throws {
        if case .object(let payloadObject) = payload {
            var mergedObject = payloadObject
            mergedObject["type"] = .string(type)
            if let title {
                mergedObject["title"] = .string(title)
            }
            try JSONValue.object(mergedObject).encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
    }
}
