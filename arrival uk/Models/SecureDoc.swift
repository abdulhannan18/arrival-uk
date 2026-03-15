import Foundation

enum SecureDocType: String, Codable, CaseIterable, Hashable {
    case passport
    case studentVisa
    case casLetter
    case tenancyAgreement
    case nationalID

    var title: String {
        switch self {
        case .passport:
            return "Passport"
        case .studentVisa:
            return "Student Visa"
        case .casLetter:
            return "CAS Letter"
        case .tenancyAgreement:
            return "Tenancy Agreement"
        case .nationalID:
            return RegionRuntime.activeConfiguration.nationalIDLabel
        }
    }

    var symbolName: String {
        switch self {
        case .passport:
            return "doc.text.fill"
        case .studentVisa:
            return "person.text.rectangle.fill"
        case .casLetter:
            return "text.below.photo.fill"
        case .tenancyAgreement:
            return "house.fill"
        case .nationalID:
            return "person.badge.key.fill"
        }
    }
}

enum SecureDocStatus: String, Codable, Hashable {
    case verified
    case pending
    case expiringSoon

    var title: String {
        switch self {
        case .verified:
            return "Verified"
        case .pending:
            return "Pending"
        case .expiringSoon:
            return "Expiring Soon"
        }
    }
}

enum SecureDocClassificationSource: String, Codable, Hashable {
    case manual
    case visionOCR = "vision_ocr"
    case remoteTemplate = "remote_template"
}

struct SecureDoc: Identifiable, Codable, Hashable {
    let id: UUID
    var type: SecureDocType
    var holderName: String
    var reference: String
    var status: SecureDocStatus
    var lastUpdatedAt: Date
    var classificationSource: SecureDocClassificationSource
    var classificationConfidence: Double?

    init(
        id: UUID = UUID(),
        type: SecureDocType,
        holderName: String,
        reference: String,
        status: SecureDocStatus,
        lastUpdatedAt: Date,
        classificationSource: SecureDocClassificationSource = .manual,
        classificationConfidence: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.holderName = holderName
        self.reference = reference
        self.status = status
        self.lastUpdatedAt = lastUpdatedAt
        self.classificationSource = classificationSource
        self.classificationConfidence = classificationConfidence
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case holderName
        case reference
        case status
        case lastUpdatedAt
        case classificationSource
        case classificationConfidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(SecureDocType.self, forKey: .type)
        holderName = try container.decode(String.self, forKey: .holderName)
        reference = try container.decode(String.self, forKey: .reference)
        status = try container.decode(SecureDocStatus.self, forKey: .status)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        classificationSource = try container.decodeIfPresent(
            SecureDocClassificationSource.self,
            forKey: .classificationSource
        ) ?? .manual
        classificationConfidence = try container.decodeIfPresent(Double.self, forKey: .classificationConfidence)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(holderName, forKey: .holderName)
        try container.encode(reference, forKey: .reference)
        try container.encode(status, forKey: .status)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(classificationSource, forKey: .classificationSource)
        try container.encodeIfPresent(classificationConfidence, forKey: .classificationConfidence)
    }
}
