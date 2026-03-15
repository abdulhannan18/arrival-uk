import SwiftUI

/// Single source of truth for category metadata that drives visual identity.
/// Keep this enum additive: when a new category is introduced, add one case and
/// populate the computed properties below.
enum AppCategory: String, CaseIterable, Identifiable, Codable {
    case beforeArrival = "Before Arrival"
    case academicSetup = "Academic Setup"
    case healthAdmin = "Health & Admin"
    case moneyBanking = "Money & Banking"
    case housingAccommodation = "Housing & Accommodation"
    case shoppingEssentials = "Shopping Essentials"
    case communicationSetup = "Communication Setup"
    case internetTech = "Internet & Tech"
    case workCareer = "Work & Career"
    case travelTransport = "Travel & Transport"
    case legalDocumentation = "Legal & Documentation"
    case insuranceSafety = "Insurance & Safety"
    case studentDiscounts = "Student Discounts"
    case socialNetworking = "Social & Networking"
    case studentLifeEssentials = "Student Life Essentials"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .beforeArrival:
            return "Must complete before landing"
        case .academicSetup:
            return "Get course systems ready"
        case .healthAdmin:
            return "Legal and healthcare setup"
        case .moneyBanking:
            return "Money setup and daily finance"
        case .housingAccommodation:
            return "Set up safe and legal housing"
        case .shoppingEssentials:
            return "Set up core living supplies"
        case .communicationSetup:
            return "Keep reliable contact channels"
        case .internetTech:
            return "Keep devices and access reliable"
        case .workCareer:
            return "Build legal work readiness"
        case .travelTransport:
            return "Move around affordably"
        case .legalDocumentation:
            return "Keep records clean and compliant"
        case .insuranceSafety:
            return "Protect yourself and belongings"
        case .studentDiscounts:
            return "Reduce ongoing monthly spend"
        case .socialNetworking:
            return "Build support and opportunities"
        case .studentLifeEssentials:
            return "Build sustainable routines"
        }
    }

    var taskCountPlaceholder: String {
        switch self {
        case .beforeArrival:
            return "1 of 4 tasks"
        case .academicSetup:
            return "0 of 3 tasks"
        case .healthAdmin:
            return "0 of 3 tasks"
        case .moneyBanking:
            return "0 of 4 tasks"
        case .housingAccommodation:
            return "0 of 5 tasks"
        case .shoppingEssentials:
            return "0 of 6 tasks"
        case .communicationSetup:
            return "0 of 2 tasks"
        case .internetTech:
            return "0 of 3 tasks"
        case .workCareer:
            return "0 of 3 tasks"
        case .travelTransport:
            return "0 of 4 tasks"
        case .legalDocumentation:
            return "0 of 3 tasks"
        case .insuranceSafety:
            return "0 of 3 tasks"
        case .studentDiscounts:
            return "0 of 5 tasks"
        case .socialNetworking:
            return "0 of 4 tasks"
        case .studentLifeEssentials:
            return "0 of 8 tasks"
        }
    }

    var iconSystemName: String {
        switch self {
        case .beforeArrival:
            return "airplane"
        case .academicSetup:
            return "graduationcap.fill"
        case .healthAdmin:
            return "cross.case.fill"
        case .moneyBanking:
            return "banknote.fill"
        case .housingAccommodation:
            return "house.fill"
        case .shoppingEssentials:
            return "bag.fill"
        case .communicationSetup:
            return "phone.fill"
        case .internetTech:
            return "wifi.router"
        case .workCareer:
            return "briefcase.fill"
        case .travelTransport:
            return "tram.fill"
        case .legalDocumentation:
            return "doc.text.magnifyingglass"
        case .insuranceSafety:
            return "shield.lefthalf.filled"
        case .studentDiscounts:
            return "percent"
        case .socialNetworking:
            return "person.2.fill"
        case .studentLifeEssentials:
            return "backpack.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .beforeArrival:
            return .indigo
        case .academicSetup:
            return .indigo
        case .healthAdmin:
            return .red
        case .moneyBanking:
            return .green
        case .housingAccommodation:
            return .blue
        case .shoppingEssentials:
            return .orange
        case .communicationSetup:
            return .teal
        case .internetTech:
            return .cyan
        case .workCareer:
            return .purple
        case .travelTransport:
            return .teal
        case .legalDocumentation:
            return .purple
        case .insuranceSafety:
            return .teal
        case .studentDiscounts:
            return .orange
        case .socialNetworking:
            return .blue
        case .studentLifeEssentials:
            return .brown
        }
    }

    var status: CategoryStatus { .week1 }

    var cardMaterial: PremiumBankCardMaterial { .standard }

    enum PremiumBankCardMaterial: String, Codable {
        case standard
    }

    private var lookupKeys: [String] {
        switch self {
        case .beforeArrival:
            return ["before_arrival", "getting_settled", "beforearrival", rawValue]
        case .academicSetup:
            return ["academic_setup", "academic", rawValue]
        case .healthAdmin:
            return ["health_admin", "admin_legal", "health", rawValue]
        case .moneyBanking:
            return ["money_banking", "daily_living", "money", rawValue]
        case .housingAccommodation:
            return ["housing", "housing_accommodation", rawValue]
        case .shoppingEssentials:
            return ["shopping_essentials", "shopping", rawValue]
        case .communicationSetup:
            return ["communication_setup", "communication", rawValue]
        case .internetTech:
            return ["internet_tech", "internet", "tech", rawValue]
        case .workCareer:
            return ["work_career", "work", rawValue]
        case .travelTransport:
            return ["travel_transport", "travel_discounts", "travel", rawValue]
        case .legalDocumentation:
            return ["legal_docs", "legal_documentation", rawValue]
        case .insuranceSafety:
            return ["insurance_safety", "insurance", rawValue]
        case .studentDiscounts:
            return ["student_discounts", "discounts", rawValue]
        case .socialNetworking:
            return ["social_networking", "social_community", "social", rawValue]
        case .studentLifeEssentials:
            return ["student_life", "student_life_essentials", rawValue]
        }
    }

    private static var lookupTable: [String: AppCategory] = {
        var table: [String: AppCategory] = [:]
        for category in AppCategory.allCases {
            for key in category.lookupKeys {
                table[normalizeKey(key)] = category
            }
        }
        return table
    }()

    private static func normalizeKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func resolve(categoryID: String, fallbackTitle: String?) -> AppCategory? {
        let idMatch = lookupTable[normalizeKey(categoryID)]
        if let idMatch { return idMatch }

        guard let fallbackTitle else { return nil }
        return lookupTable[normalizeKey(fallbackTitle)]
    }

    static func resolve(_ category: ChecklistCategory) -> AppCategory? {
        resolve(categoryID: category.id, fallbackTitle: category.title)
    }
}

enum CategoryStatus: String, Codable {
    case now = "NOW"
    case week1 = "WEEK 1"
    case week2 = "WEEK 2"
    case anytime = "ANYTIME"
}

extension ChecklistCategory {
    var appCategory: AppCategory? {
        AppCategory.resolve(self)
    }

    var resolvedIconSystemName: String {
        appCategory?.iconSystemName ?? icon
    }

    var resolvedAccentColor: Color {
        appCategory?.accentColor ?? .indigo
    }

    var resolvedDefaultSubtitle: String {
        appCategory?.subtitle ?? resolvedSubtitle
    }
}
