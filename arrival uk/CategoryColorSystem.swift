import SwiftUI
import UIKit

enum CategoryFamily: String, CaseIterable, Codable, Hashable {
    case institutionalBlue
    case financialMidnight
    case medicalEmerald
    case housingForest
    case mobilityAmber
    case careerImperial
    case communityCopper
}

enum CategoryTier: Int, CaseIterable, Codable, Hashable {
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3
    case tier4 = 4

    var validToneRange: ClosedRange<Int> {
        switch self {
        case .tier1:
            return 1 ... 4
        case .tier2:
            return 5 ... 8
        case .tier3:
            return 9 ... 12
        case .tier4:
            return 13 ... 15
        }
    }
}

struct TierGlow: Hashable {
    let opacity: Double
    let radius: CGFloat
    let yOffset: CGFloat
}

extension CategoryTier {
    var glow: TierGlow {
        switch self {
        case .tier1:
            return TierGlow(opacity: 0.45, radius: 22, yOffset: 10)
        case .tier2:
            return TierGlow(opacity: 0.35, radius: 18, yOffset: 8)
        case .tier3:
            return TierGlow(opacity: 0.25, radius: 14, yOffset: 6)
        case .tier4:
            return TierGlow(opacity: 0.18, radius: 10, yOffset: 4)
        }
    }
}

struct ArrivalCategoryColorProfile: Hashable {
    let family: CategoryFamily
    let tier: CategoryTier
    let toneIndex: Int

    init(family: CategoryFamily, tier: CategoryTier, toneIndex: Int) {
        let clampedTone = max(1, min(15, toneIndex))
        self.family = family
        self.tier = tier
        self.toneIndex = tier.validToneRange.contains(clampedTone)
            ? clampedTone
            : tier.validToneRange.lowerBound
    }
}

struct CategoryColor: Hashable {
    let family: CategoryFamily
    let tier: CategoryTier
    let toneIndex: Int
    let hex: String

    // Compatibility placeholder for legacy call sites that expect an asset name.
    var assetName: String {
        "arrival_\(family.rawValue)_t\(toneIndex)"
    }

    var color: Color {
        ArrivalColor.color(family: family, toneIndex: toneIndex)
    }
}

struct CategoryOrbTheme {
    let orbColors: [Color]
    let startAngle: Angle
    let detailCanvas: Color
    let atmosphereA: Color
    let atmosphereB: Color
    let fillAccent: Color
    let accentHex: String
    let dotColor: Color

    var orbGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: orbColors),
            center: UnitPoint(x: 0.55, y: 0.45),
            startAngle: startAngle
        )
    }
}

enum ArrivalColor {

    static let institutionalBlue: [String] = [
        "#0F3FBA", "#0F42C2", "#1045CA", "#1148D2", "#114AD9",
        "#124CE1", "#124FE7", "#1351EE", "#1353F4", "#1556F9",
        "#1758FE", "#1859FF", "#195AFF", "#1A5BFF", "#1B5CFF",
    ]

    static let financialMidnight: [String] = [
        "#19479A", "#1A499E", "#1B4BA3", "#1B4DA7", "#1C4FAB",
        "#1D50AF", "#1D52B3", "#1E54B7", "#1F56BA", "#2057BD",
        "#2159C0", "#225BC2", "#245DC5", "#255EC7", "#2660CA",
    ]

    static let medicalEmerald: [String] = [
        "#075739", "#075B3B", "#085F3D", "#086240", "#086642",
        "#096944", "#096C46", "#096F48", "#09724A", "#0A744C",
        "#0B774E", "#0C7A4F", "#0C7C51", "#0D7F53", "#0E8155",
    ]

    static let housingForest: [String] = [
        "#0B5733", "#0B5B35", "#0C5F37", "#0C6239", "#0C653A",
        "#0D683C", "#0D6B3E", "#0D6E40", "#0E7141", "#0F7343",
        "#0F7645", "#107946", "#117B48", "#127D4A", "#13804B",
    ]

    static let mobilityAmber: [String] = [
        "#7E370C", "#84390C", "#893B0D", "#8D3D0D", "#923F0D",
        "#96410E", "#9B430E", "#9F450F", "#A3470F", "#A64910",
        "#A94A11", "#AD4C12", "#B04E13", "#B35014", "#B65216",
    ]

    static let careerImperial: [String] = [
        "#6226B1", "#6628B9", "#6B2AC1", "#6F2BC8", "#732DCF",
        "#762ED6", "#7A30DC", "#7D31E3", "#8032E9", "#8434ED",
        "#8736F2", "#8A38F6", "#8D3AFB", "#8F3CFE", "#903DFF",
    ]

    static let communityCopper: [String] = [
        "#763D19", "#7B3F1A", "#80421B", "#84441C", "#89471D",
        "#8D491E", "#914B1F", "#954D20", "#994F21", "#9D5122",
        "#A05323", "#A35525", "#A65726", "#A95927", "#AC5B29",
    ]

    static let hexPalette: [CategoryFamily: [String]] = [
        .institutionalBlue: institutionalBlue,
        .financialMidnight: financialMidnight,
        .medicalEmerald: medicalEmerald,
        .housingForest: housingForest,
        .mobilityAmber: mobilityAmber,
        .careerImperial: careerImperial,
        .communityCopper: communityCopper,
    ]

    static let palette: [CategoryFamily: [Color]] = hexPalette.mapValues { ladder in
        ladder.map(Color.init(hex:))
    }

    static func color(family: CategoryFamily, toneIndex: Int) -> Color {
        guard let ladder = palette[family] else {
            let fallbackIndex = min(5, max(0, financialMidnight.count - 1))
            return financialMidnight[fallbackIndex].resolvedColor
        }

        let clampedTone = max(1, min(toneIndex, ladder.count))
        return ladder[clampedTone - 1]
    }

    static func hex(family: CategoryFamily, toneIndex: Int) -> String {
        guard let ladder = hexPalette[family] else {
            let fallbackIndex = min(5, max(0, financialMidnight.count - 1))
            return financialMidnight[fallbackIndex]
        }

        let clampedTone = max(1, min(toneIndex, ladder.count))
        return ladder[clampedTone - 1]
    }

    static func lightened(_ color: Color, by percent: Double = 0.04) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(min(brightness + CGFloat(percent), 1.0))
        )
    }
}

enum CategoryColorSystem {
    private static let defaultProfile = ArrivalCategoryColorProfile(
        family: .financialMidnight,
        tier: .tier2,
        toneIndex: 6
    )

    static func color(for category: ChecklistCategory, index _: Int) -> CategoryColor {
        let profile = profile(for: category)
        return CategoryColor(
            family: profile.family,
            tier: profile.tier,
            toneIndex: profile.toneIndex,
            hex: ArrivalColor.hex(family: profile.family, toneIndex: profile.toneIndex)
        )
    }

    static func color(forID id: String, index: Int) -> CategoryColor {
        let appCategory = AppCategory.resolve(categoryID: id, fallbackTitle: nil)
        let profile = profile(for: appCategory, fallbackSeed: stableSeed(for: id), priority: nil, index: index)

        return CategoryColor(
            family: profile.family,
            tier: profile.tier,
            toneIndex: profile.toneIndex,
            hex: ArrivalColor.hex(family: profile.family, toneIndex: profile.toneIndex)
        )
    }

    static func orbTheme(for category: ChecklistCategory, index: Int) -> CategoryOrbTheme {
        let appCategory = category.appCategory
        let fallbackBaseColor = color(for: category, index: index).color
        return orbTheme(for: appCategory, fallbackColor: fallbackBaseColor)
    }

    static func orbTheme(forID id: String, index: Int) -> CategoryOrbTheme {
        let appCategory = AppCategory.resolve(categoryID: id, fallbackTitle: nil)
        let fallbackBaseColor = color(forID: id, index: index).color
        return orbTheme(for: appCategory, fallbackColor: fallbackBaseColor)
    }

    static func gradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private static func profile(for category: ChecklistCategory) -> ArrivalCategoryColorProfile {
        let appCategory = category.appCategory
        return profile(
            for: appCategory,
            fallbackSeed: stableSeed(for: category.id),
            priority: category.visualPriority,
            index: category.order ?? 0
        )
    }

    private static func profile(
        for appCategory: AppCategory?,
        fallbackSeed: Int,
        priority: CategoryPriorityLevel?,
        index: Int
    ) -> ArrivalCategoryColorProfile {
        if let appCategory, let mapped = profileByAppCategory[appCategory] {
            return mapped
        }

        let tier = tier(for: priority)
        let normalizedSeed = normalized(seed: fallbackSeed)
        let family = CategoryFamily.allCases[normalizedSeed % CategoryFamily.allCases.count]
        let toneRange = Array(tier.validToneRange)
        let toneOffset = normalized(seed: index &+ normalizedSeed)
        let tone = toneRange[toneOffset % toneRange.count]

        return ArrivalCategoryColorProfile(family: family, tier: tier, toneIndex: tone)
    }

    private static func tier(for priority: CategoryPriorityLevel?) -> CategoryTier {
        switch priority {
        case .critical:
            return .tier1
        case .high:
            return .tier2
        case .medium:
            return .tier3
        case .low:
            return .tier4
        case .none:
            return defaultProfile.tier
        }
    }

    private static func stableSeed(for value: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash & 0x7FFF_FFFF)
    }

    private static func normalized(seed: Int) -> Int {
        seed == Int.min ? 0 : abs(seed)
    }

    private static func orbTheme(for appCategory: AppCategory?, fallbackColor: Color) -> CategoryOrbTheme {
        if let appCategory, let theme = orbThemeByCategory[appCategory] {
            return theme
        }
        return fallbackOrbTheme(from: fallbackColor)
    }

    private static func fallbackOrbTheme(from baseColor: Color) -> CategoryOrbTheme {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let primary = Color(
            hue: hue,
            saturation: min(max(saturation * 0.9, 0.20), 1.0),
            brightness: min(max(brightness * 1.05, 0.55), 1.0),
            opacity: 0.92
        )
        let secondary = Color(
            hue: fmod(hue + 0.08, 1.0),
            saturation: min(max(saturation * 0.7, 0.18), 1.0),
            brightness: min(max(brightness * 1.12, 0.62), 1.0),
            opacity: 0.92
        )
        let tertiary = Color(
            hue: fmod(hue + 0.16, 1.0),
            saturation: min(max(saturation * 0.75, 0.20), 1.0),
            brightness: min(max(brightness * 1.14, 0.65), 1.0),
            opacity: 0.90
        )

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let canvas = Color(
            .sRGB,
            red: Double(min(1, red * 0.14 + 0.86)),
            green: Double(min(1, green * 0.14 + 0.86)),
            blue: Double(min(1, blue * 0.14 + 0.86)),
            opacity: 1
        )

        return CategoryOrbTheme(
            orbColors: [primary, secondary, tertiary, secondary, primary, primary],
            startAngle: .degrees(100),
            detailCanvas: canvas,
            atmosphereA: Color(uiColor: uiColor),
            atmosphereB: secondary.opacity(1),
            fillAccent: Color(uiColor: uiColor).opacity(0.48),
            accentHex: "#5B7CFF",
            dotColor: Color(uiColor: uiColor).opacity(0.85)
        )
    }

    private static let profileByAppCategory: [AppCategory: ArrivalCategoryColorProfile] = [
        .beforeArrival: .init(family: .institutionalBlue, tier: .tier1, toneIndex: 4),
        .academicSetup: .init(family: .institutionalBlue, tier: .tier2, toneIndex: 6),
        .healthAdmin: .init(family: .medicalEmerald, tier: .tier1, toneIndex: 2),
        .moneyBanking: .init(family: .financialMidnight, tier: .tier1, toneIndex: 3),
        .housingAccommodation: .init(family: .housingForest, tier: .tier2, toneIndex: 5),
        .shoppingEssentials: .init(family: .communityCopper, tier: .tier2, toneIndex: 8),
        .communicationSetup: .init(family: .financialMidnight, tier: .tier2, toneIndex: 5),
        .internetTech: .init(family: .financialMidnight, tier: .tier2, toneIndex: 7),
        .workCareer: .init(family: .careerImperial, tier: .tier3, toneIndex: 9),
        .travelTransport: .init(family: .mobilityAmber, tier: .tier2, toneIndex: 6),
        .legalDocumentation: .init(family: .institutionalBlue, tier: .tier1, toneIndex: 2),
        .insuranceSafety: .init(family: .medicalEmerald, tier: .tier2, toneIndex: 5),
        .studentDiscounts: .init(family: .communityCopper, tier: .tier3, toneIndex: 9),
        .socialNetworking: .init(family: .communityCopper, tier: .tier3, toneIndex: 11),
        .studentLifeEssentials: .init(family: .communityCopper, tier: .tier3, toneIndex: 10),
    ]

    private static let orbThemeByCategory: [AppCategory: CategoryOrbTheme] = [
        .moneyBanking: CategoryOrbTheme(
            orbColors: [
                rgba(255, 180, 200, 0.92),
                rgba(180, 222, 255, 0.96),
                rgba(180, 255, 222, 0.92),
                rgba(255, 242, 168, 0.90),
                rgba(210, 170, 255, 0.92),
                rgba(255, 180, 200, 0.92),
            ],
            startAngle: .degrees(100),
            detailCanvas: Color(hex: "F0ECF8"),
            atmosphereA: rgba(200, 160, 255, 1),
            atmosphereB: rgba(160, 220, 255, 1),
            fillAccent: rgba(160, 100, 255, 0.48),
            accentHex: "#9060E0",
            dotColor: Color(hex: "B080FF")
        ),
        .internetTech: CategoryOrbTheme(
            orbColors: [
                rgba(80, 205, 255, 0.94),
                rgba(80, 255, 218, 0.90),
                rgba(120, 255, 235, 0.88),
                rgba(80, 220, 255, 0.90),
                rgba(62, 198, 255, 0.92),
                rgba(80, 205, 255, 0.94),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "EAF4FC"),
            atmosphereA: rgba(80, 200, 255, 1),
            atmosphereB: rgba(60, 255, 200, 1),
            fillAccent: rgba(40, 178, 255, 0.52),
            accentHex: "#1890E8",
            dotColor: Color(hex: "40C0FF")
        ),
        .healthAdmin: CategoryOrbTheme(
            orbColors: [
                rgba(80, 222, 158, 0.95),
                rgba(40, 198, 118, 0.90),
                rgba(120, 236, 182, 0.88),
                rgba(56, 216, 140, 0.90),
                rgba(38, 176, 108, 0.92),
                rgba(80, 222, 158, 0.95),
            ],
            startAngle: .degrees(98),
            detailCanvas: Color(hex: "EAF8F0"),
            atmosphereA: rgba(60, 200, 130, 1),
            atmosphereB: rgba(80, 240, 160, 1),
            fillAccent: rgba(40, 180, 118, 0.52),
            accentHex: "#10A060",
            dotColor: Color(hex: "40D090")
        ),
        .housingAccommodation: CategoryOrbTheme(
            orbColors: [
                rgba(80, 162, 255, 0.92),
                rgba(60, 132, 255, 0.96),
                rgba(108, 168, 255, 0.90),
                rgba(78, 146, 255, 0.92),
                rgba(52, 120, 250, 0.92),
                rgba(80, 162, 255, 0.92),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "EAEFFC"),
            atmosphereA: rgba(60, 140, 255, 1),
            atmosphereB: rgba(80, 180, 255, 1),
            fillAccent: rgba(60, 142, 255, 0.52),
            accentHex: "#1860E0",
            dotColor: Color(hex: "60A0FF")
        ),
        .studentDiscounts: CategoryOrbTheme(
            orbColors: [
                rgba(255, 200, 80, 0.92),
                rgba(255, 160, 40, 0.94),
                rgba(255, 222, 120, 0.90),
                rgba(255, 182, 80, 0.92),
                rgba(255, 150, 32, 0.92),
                rgba(255, 200, 80, 0.92),
            ],
            startAngle: .degrees(96),
            detailCanvas: Color(hex: "FDF5E6"),
            atmosphereA: rgba(255, 180, 40, 1),
            atmosphereB: rgba(255, 220, 80, 1),
            fillAccent: rgba(255, 180, 40, 0.52),
            accentHex: "#D08000",
            dotColor: Color(hex: "FFA830")
        ),
        .workCareer: CategoryOrbTheme(
            orbColors: [
                rgba(232, 40, 112, 0.90),
                rgba(255, 100, 160, 0.88),
                rgba(246, 88, 146, 0.90),
                rgba(220, 52, 118, 0.90),
                rgba(198, 32, 94, 0.92),
                rgba(232, 40, 112, 0.90),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "FDF0F5"),
            atmosphereA: rgba(232, 40, 112, 1),
            atmosphereB: rgba(255, 100, 160, 1),
            fillAccent: rgba(220, 30, 100, 0.52),
            accentHex: "#C0104E",
            dotColor: Color(hex: "E83070")
        ),
        .academicSetup: CategoryOrbTheme(
            orbColors: [
                rgba(180, 140, 255, 0.90),
                rgba(120, 100, 255, 0.90),
                rgba(164, 126, 255, 0.90),
                rgba(138, 114, 255, 0.90),
                rgba(110, 90, 240, 0.92),
                rgba(180, 140, 255, 0.90),
            ],
            startAngle: .degrees(100),
            detailCanvas: Color(hex: "F4F0FC"),
            atmosphereA: rgba(160, 120, 255, 1),
            atmosphereB: rgba(120, 100, 255, 1),
            fillAccent: rgba(140, 100, 255, 0.52),
            accentHex: "#6040C0",
            dotColor: Color(hex: "B080FF")
        ),
        .beforeArrival: CategoryOrbTheme(
            orbColors: [
                rgba(255, 140, 60, 0.92),
                rgba(255, 180, 60, 0.90),
                rgba(255, 162, 72, 0.92),
                rgba(255, 206, 104, 0.90),
                rgba(242, 122, 52, 0.92),
                rgba(255, 140, 60, 0.92),
            ],
            startAngle: .degrees(96),
            detailCanvas: Color(hex: "FDF4EC"),
            atmosphereA: rgba(255, 140, 60, 1),
            atmosphereB: rgba(255, 200, 80, 1),
            fillAccent: rgba(240, 120, 40, 0.52),
            accentHex: "#D06010",
            dotColor: Color(hex: "FF8C3C")
        ),

        // Mapped extensions for additional product categories so visuals stay consistent.
        .communicationSetup: CategoryOrbTheme(
            orbColors: [
                rgba(80, 205, 255, 0.94),
                rgba(80, 255, 218, 0.90),
                rgba(120, 255, 235, 0.88),
                rgba(80, 220, 255, 0.90),
                rgba(62, 198, 255, 0.92),
                rgba(80, 205, 255, 0.94),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "EAF4FC"),
            atmosphereA: rgba(80, 200, 255, 1),
            atmosphereB: rgba(60, 255, 200, 1),
            fillAccent: rgba(40, 178, 255, 0.52),
            accentHex: "#1890E8",
            dotColor: Color(hex: "40C0FF")
        ),
        .travelTransport: CategoryOrbTheme(
            orbColors: [
                rgba(80, 162, 255, 0.92),
                rgba(60, 132, 255, 0.96),
                rgba(108, 168, 255, 0.90),
                rgba(78, 146, 255, 0.92),
                rgba(52, 120, 250, 0.92),
                rgba(80, 162, 255, 0.92),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "EAEFFC"),
            atmosphereA: rgba(60, 140, 255, 1),
            atmosphereB: rgba(80, 180, 255, 1),
            fillAccent: rgba(60, 142, 255, 0.52),
            accentHex: "#1860E0",
            dotColor: Color(hex: "60A0FF")
        ),
        .legalDocumentation: CategoryOrbTheme(
            orbColors: [
                rgba(180, 140, 255, 0.90),
                rgba(120, 100, 255, 0.90),
                rgba(164, 126, 255, 0.90),
                rgba(138, 114, 255, 0.90),
                rgba(110, 90, 240, 0.92),
                rgba(180, 140, 255, 0.90),
            ],
            startAngle: .degrees(100),
            detailCanvas: Color(hex: "F4F0FC"),
            atmosphereA: rgba(160, 120, 255, 1),
            atmosphereB: rgba(120, 100, 255, 1),
            fillAccent: rgba(140, 100, 255, 0.52),
            accentHex: "#6040C0",
            dotColor: Color(hex: "B080FF")
        ),
        .insuranceSafety: CategoryOrbTheme(
            orbColors: [
                rgba(80, 222, 158, 0.95),
                rgba(40, 198, 118, 0.90),
                rgba(120, 236, 182, 0.88),
                rgba(56, 216, 140, 0.90),
                rgba(38, 176, 108, 0.92),
                rgba(80, 222, 158, 0.95),
            ],
            startAngle: .degrees(98),
            detailCanvas: Color(hex: "EAF8F0"),
            atmosphereA: rgba(60, 200, 130, 1),
            atmosphereB: rgba(80, 240, 160, 1),
            fillAccent: rgba(40, 180, 118, 0.52),
            accentHex: "#10A060",
            dotColor: Color(hex: "40D090")
        ),
        .shoppingEssentials: CategoryOrbTheme(
            orbColors: [
                rgba(255, 200, 80, 0.92),
                rgba(255, 160, 40, 0.94),
                rgba(255, 222, 120, 0.90),
                rgba(255, 182, 80, 0.92),
                rgba(255, 150, 32, 0.92),
                rgba(255, 200, 80, 0.92),
            ],
            startAngle: .degrees(96),
            detailCanvas: Color(hex: "FDF5E6"),
            atmosphereA: rgba(255, 180, 40, 1),
            atmosphereB: rgba(255, 220, 80, 1),
            fillAccent: rgba(255, 180, 40, 0.52),
            accentHex: "#D08000",
            dotColor: Color(hex: "FFA830")
        ),
        .socialNetworking: CategoryOrbTheme(
            orbColors: [
                rgba(232, 40, 112, 0.90),
                rgba(255, 100, 160, 0.88),
                rgba(246, 88, 146, 0.90),
                rgba(220, 52, 118, 0.90),
                rgba(198, 32, 94, 0.92),
                rgba(232, 40, 112, 0.90),
            ],
            startAngle: .degrees(102),
            detailCanvas: Color(hex: "FDF0F5"),
            atmosphereA: rgba(232, 40, 112, 1),
            atmosphereB: rgba(255, 100, 160, 1),
            fillAccent: rgba(220, 30, 100, 0.52),
            accentHex: "#C0104E",
            dotColor: Color(hex: "E83070")
        ),
        .studentLifeEssentials: CategoryOrbTheme(
            orbColors: [
                rgba(255, 180, 200, 0.92),
                rgba(180, 222, 255, 0.96),
                rgba(180, 255, 222, 0.92),
                rgba(255, 242, 168, 0.90),
                rgba(210, 170, 255, 0.92),
                rgba(255, 180, 200, 0.92),
            ],
            startAngle: .degrees(100),
            detailCanvas: Color(hex: "F0ECF8"),
            atmosphereA: rgba(200, 160, 255, 1),
            atmosphereB: rgba(160, 220, 255, 1),
            fillAccent: rgba(160, 100, 255, 0.48),
            accentHex: "#9060E0",
            dotColor: Color(hex: "B080FF")
        ),
    ]

    private static func rgba(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> Color {
        Color(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: alpha
        )
    }
}

private extension String {
    var resolvedColor: Color {
        Color(hex: self)
    }
}
