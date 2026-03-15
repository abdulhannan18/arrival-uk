import SwiftUI

enum CategoryPriorityLevel: String, Codable, CaseIterable, Hashable {
    case critical
    case high
    case medium
    case low

    var ranking: Int {
        switch self {
        case .critical:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }

    static func fromLegacy(priority: Int) -> CategoryPriorityLevel {
        switch priority {
        case ..<2:
            return .critical
        case 2:
            return .high
        case 3:
            return .medium
        default:
            return .low
        }
    }
}

enum CategoryUrgencyBand: String, Codable, Hashable {
    case immediate
    case week1
    case week2
    case anytime
    case completed

    var ranking: Int {
        switch self {
        case .immediate:
            return 0
        case .week1:
            return 1
        case .week2:
            return 2
        case .anytime:
            return 3
        case .completed:
            return 4
        }
    }
}

enum CategoryAccentStyle: Hashable {
    case gradient
    case solidBorder
    case tintedBackground
    case icon
}

enum CategoryShadowLevel: Hashable {
    case none
    case subtle
    case medium
    case elevated
}

struct CategoryVisualStyle: Hashable {
    let minHeight: CGFloat
    let cornerRadius: CGFloat
    let titleFontSize: CGFloat
    let titleWeight: Font.Weight
    let titleTracking: CGFloat
    let subtitleFontSize: CGFloat
    let subtitleWeight: Font.Weight
    let subtitleOpacity: Double
    let metaFontSize: CGFloat
    let iconSize: CGFloat
    let borderWidth: CGFloat
    let accentStyle: CategoryAccentStyle
    let shadowLevel: CategoryShadowLevel
    let cardPadding: CGFloat
}

enum CategoryVisualHierarchy {
    private static let styles: [CategoryPriorityLevel: CategoryVisualStyle] = [
        .critical: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .bold,
            titleTracking: -0.2,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .gradient,
            shadowLevel: .elevated,
            cardPadding: 16
        ),
        .high: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .bold,
            titleTracking: -0.2,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .solidBorder,
            shadowLevel: .medium,
            cardPadding: 16
        ),
        .medium: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .semibold,
            titleTracking: -0.1,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .tintedBackground,
            shadowLevel: .medium,
            cardPadding: 16
        ),
        .low: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 18,
            titleWeight: .semibold,
            titleTracking: -0.1,
            subtitleFontSize: 13,
            subtitleWeight: .regular,
            subtitleOpacity: 0.82,
            metaFontSize: 13,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .icon,
            shadowLevel: .subtle,
            cardPadding: 16
        )
    ]

    static func getVisualStyle(_ priority: CategoryPriorityLevel) -> CategoryVisualStyle {
        if let resolved = styles[priority] {
            return resolved
        }
        if let fallback = styles[.medium] {
            return fallback
        }
        return CategoryVisualStyle(
            minHeight: 140,
            cornerRadius: 22,
            titleFontSize: 20,
            titleWeight: .semibold,
            titleTracking: 0,
            subtitleFontSize: 12,
            subtitleWeight: .regular,
            subtitleOpacity: 0.78,
            metaFontSize: 12,
            iconSize: 42,
            borderWidth: 0,
            accentStyle: .tintedBackground,
            shadowLevel: .medium,
            cardPadding: 18
        )
    }
}

