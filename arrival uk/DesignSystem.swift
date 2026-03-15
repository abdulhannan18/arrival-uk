import SwiftUI
import UIKit
import os

struct CategoryPalette: Hashable {
    let start: Color
    let end: Color

    var fill: Color {
        start
    }

    var gradient: Color {
        start
    }

    var linearGradient: LinearGradient {
        LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var shadowColor: Color {
        start
    }
}

enum LayerZIndex {
    static let base: Double = 0
    static let stickyHeader: Double = 100
    static let overlayScrim: Double = 1000
    static let categoryOverlay: Double = 1050
    static let modal: Double = 1100
}

enum Theme {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let spaceXXL: CGFloat = 24
    static let spaceXXXL: CGFloat = 32
    static let spaceHuge: CGFloat = 48

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 24

    static let bottomBarReserve: CGFloat = 118

    // Home Theme Palette
    static let navy50 = color(0xEEF2FF)
    static let navy100 = color(0xE0E7FF)
    static let navy200 = color(0xC7D2FE)
    static let navy300 = color(0xA5B4FC)
    static let navy400 = color(0x818CF8)
    static let navy500 = color(0x6366F1)
    static let navy600 = color(0x4F46E5)
    static let navy700 = color(0x4338CA)
    static let navy800 = color(0x312E81)
    static let navy900 = color(0x1A1A2E)

    static let brandPrimary = color(0x5B7CFF)
    static let brandSecondary = color(0x7C3AED)
    static let primaryMain = brandPrimary
    static let primaryLight = color(0x7D95FF)
    static let primaryDark = brandSecondary

    static let beforeArrivalStart = color(0x667EEA)
    static let beforeArrivalEnd = color(0x764BA2)
    static let healthStart = color(0xF093FB)
    static let healthEnd = color(0xF5576C)
    static let moneyStart = color(0xFCCF31)
    static let moneyEnd = color(0xF55555)
    static let travelStart = color(0x4FACFE)
    static let travelEnd = color(0x00F2FE)

    static let reserveCategory5Start = color(0xA8EDEA)
    static let reserveCategory5End = color(0x6DD5FA)
    static let reserveCategory6Start = color(0xD299C2)
    static let reserveCategory6End = color(0xFEF9D7)
    static let reserveCategory7Start = color(0xFDCBF1)
    static let reserveCategory7End = color(0xE6DEE9)
    static let reserveCategory8Start = color(0xFFC371)
    static let reserveCategory8End = color(0xFF5F6D)

    static let terracotta50 = color(0xFDF5F3)
    static let terracotta100 = color(0xFAE6E0)
    static let terracotta200 = color(0xF5CCBD)
    static let terracotta300 = color(0xF0B39A)
    static let terracotta400 = color(0xEA9A77)
    static let terracotta500 = color(0xE07A5F)
    static let terracotta600 = color(0xD66849)
    static let terracotta700 = color(0xC25437)
    static let terracotta800 = color(0xA0442D)
    static let terracotta900 = color(0x7E3423)

    static let sage50 = color(0xF2F7F5)
    static let sage100 = color(0xE0EBE6)
    static let sage200 = color(0xC1D7CE)
    static let sage300 = color(0xA2C3B5)
    static let sage400 = color(0x92BBAA)
    static let sage500 = color(0x5CAE7F)
    static let sage600 = color(0x319795)
    static let sage700 = color(0x2C7A7B)
    static let sage800 = color(0x285E61)
    static let sage900 = color(0x234E52)

    static let warmOrange50 = color(0xFEF8F3)
    static let warmOrange100 = color(0xFDEEE0)
    static let warmOrange200 = color(0xFBDDC1)
    static let warmOrange300 = color(0xF8CCA2)
    static let warmOrange400 = color(0xF6B882)
    static let warmOrange500 = color(0xFFAB47)
    static let warmOrange600 = color(0xB7791F)
    static let warmOrange700 = color(0x975A16)
    static let warmOrange800 = color(0x744210)
    static let warmOrange900 = color(0x5F370E)

    static let cream50 = color(0xFFFFFF)
    static let cream100 = color(0xFFFFFF)
    static let cream200 = color(0xF8F9FF)
    static let cream300 = color(0xF1F3FF)
    static let cream400 = color(0xE5E7EB)
    static let cream500 = color(0xCBD5E1)

    // Warm luxury neutrals
    static let warmBase50 = color(0xFDFCFB)
    static let warmBase100 = color(0xFAF8F5)
    static let warmBase200 = color(0xF4F1EC)
    static let luxuryGold = color(0xF59E0B)
    static let luxuryGoldBorder = color(0xF59E0B, alpha: 0.20)
    static let cosmicBlue = color(0x1E3A8A)
    static let actionGradientStart = color(0xED7D4D)
    static let actionGradientEnd = color(0xE85D40)

    static let gray50 = color(0xF8F9FA)
    static let gray100 = color(0xF1F3F5)
    static let gray200 = color(0xE9ECEF)
    static let gray300 = color(0xDEE2E6)
    static let gray400 = color(0xCED4DA)
    static let gray500 = color(0x94A3B8)
    static let gray600 = color(0x9CA3AF)
    static let gray700 = color(0x6B7280)
    static let gray800 = color(0x343A40)
    static let gray900 = color(0x212529)

    static let successLight = color(0xD4E7DD)
    static let successMain = color(0x22C55E)
    static let successDark = color(0x2F855A)
    static let warningLight = color(0xFDEEE0)
    static let warningMain = color(0xED8936)
    static let warningDark = color(0xC05621)
    static let errorLight = color(0xF8D7DA)
    static let errorMain = color(0xFC8181)
    static let errorDark = color(0xC53030)
    static let infoLight = color(0xD9E2EC)
    static let infoMain = color(0x4299E1)
    static let infoDark = color(0x2B6CB0)

    static let teal500 = color(0x38B2AC)
    static let purple500 = color(0x667EEA)
    static let amber500 = color(0xD69E2E)
    static let rose500 = color(0xFC8181)
    static let indigo500 = color(0x667EEA)
    static let olive500 = color(0x48BB78)
    static let coral500 = color(0xFC8181)
    static let sky500 = color(0x4299E1)

    // Home card specific colors
    static let moneyCardGradientStart = color(0xFFAB47)
    static let moneyCardGradientEnd = color(0xF08D42)
    static let travelCardGradientStart = color(0x4BC4D9)
    static let travelCardGradientEnd = color(0x5B92F6)
    static let workCardSolid = color(0x7B68EE)

    static let accent = brandPrimary
    static let accentSoft = primaryDark
    static let inverseText = color(0xFFFFFF)
    static let linkText = brandPrimary
    static let backgroundPrimary = warmBase100
    static let backgroundSecondary = color(0xFFFFFF)

    static let primaryText = color(0x1F2937)
    static let secondaryText = color(0x6B7280)
    static let tertiaryText = color(0x9CA3AF)

    static let brandGradient: Color = primaryMain

    static let track = color(0xEEF0F3)
    static let card = color(0xFFFFFF)
    static let stroke = color(0xEBEDF1)
    static let strokeStrong = color(0xD7DCE3)

    static let shadowSoft = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.08)
    static let shadowElevated = Color.black.opacity(0.12)
    static let shadowCritical = navy900.opacity(0.15)
    static let modalScrim = Color.black.opacity(0.50)

    static let navBarBackground = color(0xFFFFFF)
    static let navActive = navy900
    static let navActiveBackground = navy50

    static let primaryButtonBackground = brandPrimary
    static let primaryButtonPressed = brandSecondary

    static func palette(for categoryID: String) -> CategoryPalette {
        let resolved = CategoryColorSystem.color(forID: categoryID, index: 0).color
        return CategoryPalette(start: resolved, end: resolved)
    }

    static func palette(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> CategoryPalette {
        let fallbackIndex = categories.firstIndex(where: { $0.id == category.id }) ?? 0
        let resolved = CategoryColorSystem.color(for: category, index: category.order ?? fallbackIndex).color
        return CategoryPalette(start: resolved, end: resolved)
    }

    static func urgencyColor(_ urgency: CategoryUrgencyBand) -> Color {
        switch urgency {
        case .immediate:
            return color(0xD94F4F)
        case .week1:
            return warmOrange600
        case .week2:
            return navy500
        case .anytime:
            return warmOrange500
        case .completed:
            return successMain
        }
    }

    static func sourceTint(for sourceType: SourceTrustType) -> Color {
        switch sourceType {
        case .official:
            return navy900
        case .university:
            return sage700
        case .partner:
            return warmOrange700
        case .community:
            return terracotta700
        case .editorial:
            return navy700
        case .unknown:
            return gray700
        }
    }

    static func categoryBackground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        palette(for: category, among: categories).fill
    }

    static func categoryText(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        categoryUsesDarkForeground(for: category, among: categories) ? navy900 : inverseText
    }

    static func categoryBadgeBackground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        if category.urgencyBand == .completed {
            return successLight
        }

        switch category.visualPriority {
        case .critical:
            return terracotta500
        case .high:
            return cream200
        case .medium:
            return navy900
        case .low:
            return color(0xFFFFFF)
        }
    }

    static func categoryBadgeText(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        if category.urgencyBand == .completed {
            return successDark
        }

        switch category.visualPriority {
        case .critical, .medium:
            return inverseText
        case .high, .low:
            return navy900
        }
    }

    static func categoryUsesDarkForeground(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Bool {
        return false
    }

    static func accentColor(for category: ChecklistCategory, among categories: [ChecklistCategory] = []) -> Color {
        categoryBackground(for: category, among: categories)
    }

    @ViewBuilder
    static func background(for _: ColorScheme, conservative: Bool) -> some View {
        if conservative {
            color(0x0A0A0A)
        } else {
            LinearGradient(
                colors: [color(0x0A0A0A), color(0x121212)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> Color {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }

    private static func color(fromHexString value: String) -> Color? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let hex = UInt32(cleaned, radix: 16) else {
            return nil
        }

        return color(hex)
    }

    private static func canonicalCategoryID(_ rawID: String) -> String {
        rawID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func normalizedCategoryType(_ rawType: String?) -> String? {
        guard let rawType, !rawType.isEmpty else { return nil }
        return rawType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func typeColor(for category: ChecklistCategory) -> Color? {
        switch normalizedCategoryType(category.categoryType) {
        case "housing":
            return teal500
        case "academic":
            return purple500
        case "shopping":
            return amber500
        case "wellness":
            return rose500
        case "finance":
            return indigo500
        case "transport":
            return olive500
        case "social":
            return coral500
        case "travel":
            return sky500
        default:
            return nil
        }
    }

    private static func gradientPool() -> [CategoryPalette] {
        [
            CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd),
            CategoryPalette(start: healthStart, end: healthEnd),
            CategoryPalette(start: moneyStart, end: moneyEnd),
            CategoryPalette(start: travelStart, end: travelEnd),
            CategoryPalette(start: reserveCategory5Start, end: reserveCategory5End),
            CategoryPalette(start: reserveCategory6Start, end: reserveCategory6End),
            CategoryPalette(start: reserveCategory7Start, end: reserveCategory7End),
            CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
        ]
    }

    private static func colorPool(for priority: CategoryPriorityLevel) -> [CategoryPalette] {
        switch priority {
        case .critical:
            return [CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd)]
        case .high:
            return [
                CategoryPalette(start: healthStart, end: healthEnd),
                CategoryPalette(start: reserveCategory6Start, end: reserveCategory6End)
            ]
        case .medium:
            return [
                CategoryPalette(start: moneyStart, end: moneyEnd),
                CategoryPalette(start: reserveCategory5Start, end: reserveCategory5End)
            ]
        case .low:
            return [
                CategoryPalette(start: travelStart, end: travelEnd),
                CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
            ]
        }
    }

    private static func legacyKnownCategoryGradient(forID categoryID: String) -> CategoryPalette? {
        switch canonicalCategoryID(categoryID) {
        case "before_arrival", "getting_settled":
            return CategoryPalette(start: navy900, end: navy900)
        case "health_admin", "admin_legal":
            return CategoryPalette(start: sage500, end: sage500)
        case "work_career":
            return CategoryPalette(start: workCardSolid, end: workCardSolid)
        case "money_banking", "daily_living":
            return CategoryPalette(start: moneyCardGradientStart, end: moneyCardGradientEnd)
        case "travel_discounts":
            return CategoryPalette(start: travelCardGradientStart, end: travelCardGradientEnd)
        case "social":
            return CategoryPalette(start: reserveCategory8Start, end: reserveCategory8End)
        default:
            return nil
        }
    }

    private static func alternatingPriorityPalette(for category: ChecklistCategory, among categories: [ChecklistCategory]) -> CategoryPalette {
        let palette = colorPool(for: category.visualPriority)
        guard palette.count > 1 else { return palette.first ?? CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd) }

        let samePriority = categories
            .filter { $0.visualPriority == category.visualPriority && $0.isVisible }
            .sorted { left, right in
                if left.order != right.order {
                    return (left.order ?? .max) < (right.order ?? .max)
                }
                return left.id < right.id
            }

        guard let index = samePriority.firstIndex(where: { $0.id == category.id }) else {
            return palette[0]
        }
        return palette[index % palette.count]
    }

    private static func resolvedCategoryPalette(for category: ChecklistCategory, among categories: [ChecklistCategory]) -> CategoryPalette {
        if let gradient = category.gradient, gradient.count >= 2 {
            let startHex = gradient[0]
            let endHex = gradient[1]
            if let startColor = color(fromHexString: startHex), let endColor = color(fromHexString: endHex) {
                return CategoryPalette(start: startColor, end: endColor)
            }
        }

        if let customHex = category.accentColorHex, let custom = color(fromHexString: customHex) {
            return CategoryPalette(start: custom, end: custom)
        }

        if let typedColor = typeColor(for: category) {
            return CategoryPalette(start: typedColor, end: typedColor)
        }

        if let known = legacyKnownCategoryGradient(forID: category.id) {
            return known
        }

        if !categories.isEmpty {
            return alternatingPriorityPalette(for: category, among: categories)
        }

        let pool = gradientPool()
        let stableIndex = abs(category.id.hashValue) % pool.count
        if pool.indices.contains(stableIndex) {
            return pool[stableIndex]
        }

        return CategoryPalette(start: beforeArrivalStart, end: beforeArrivalEnd)
    }

    private struct RGBColor {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        var relativeLuminance: CGFloat {
            (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }
    }

    private static func rgb(fromHexString value: String) -> RGBColor? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let hex = UInt32(cleaned, radix: 16) else {
            return nil
        }

        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return RGBColor(red: red, green: green, blue: blue)
    }
}

struct CardChromeModifier: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .shadow(
                color: elevated ? Theme.shadowMedium : Theme.shadowSoft,
                radius: elevated ? 8 : 2,
                x: 0,
                y: elevated ? 4 : 1
            )
    }
}

struct GlassSheetPresentationModifier: ViewModifier {
    let conservative: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .presentationBackground(Theme.card)
        } else if conservative {
            content
                .presentationBackground(.thinMaterial)
        } else {
            content
                .presentationBackground(.regularMaterial)
        }
    }
}

extension View {
    func cardChrome(elevated: Bool) -> some View {
        modifier(CardChromeModifier(elevated: elevated))
    }

    func glassSheetPresentation(conservative: Bool) -> some View {
        modifier(GlassSheetPresentationModifier(conservative: conservative))
    }

    func staggeredEntry(index: Int, isActive: Bool, prefersReducedMotion: Bool) -> some View {
        modifier(
            StaggeredEntryModifier(
                index: index,
                isActive: isActive,
                prefersReducedMotion: prefersReducedMotion
            )
        )
    }
}

struct StaggeredEntryModifier: ViewModifier {
    let index: Int
    let isActive: Bool
    let prefersReducedMotion: Bool

    func body(content: Content) -> some View {
        let isVisible = isActive || prefersReducedMotion

        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.98, anchor: .top)
            .animation(
                Motion.staggeredEntry(index: index, prefersReducedMotion: prefersReducedMotion),
                value: isActive
            )
    }
}

enum Motion {
    private static var systemPrefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || PerformanceProfile.prefersConservativeVisuals
    }

    @MainActor
    static func mutate(_ updates: () -> Void) {
        if systemPrefersReducedMotion {
            updates()
        } else {
            withAnimation(screenTransition(prefersReducedMotion: false)) {
                updates()
            }
        }
    }

    static func pressDown(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.06)
        }
        return .easeOut(duration: 0.10)
    }

    static func pressUp(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.12)
        }
        return .spring(response: 0.20, dampingFraction: 0.70)
    }

    static func launchEntrance(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .spring(response: 0.40, dampingFraction: 0.75)
    }

    static func screenTransition(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.18)
        }
        return .easeInOut(duration: 0.30)
    }

    static func modalAppear(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .easeOut(duration: 0.30)
    }

    static func modalDismiss(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeIn(duration: 0.14)
        }
        return .easeIn(duration: 0.20)
    }

    static func heroExpand(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.20)
        }
        return .timingCurve(0.32, 0.72, 0, 1, duration: 0.62)
    }

    static func heroExpandDuration(prefersReducedMotion: Bool) -> TimeInterval {
        if prefersReducedMotion {
            return 0.20
        }
        return 0.62
    }

    static func heroCollapse(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.18)
        }
        return .timingCurve(0.32, 0.72, 0, 1, duration: 0.62)
    }

    static func heroReveal(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        return .easeOut(duration: 0.30)
    }

    static func heroBackground(prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeInOut(duration: 0.14)
        }
        return .timingCurve(0.32, 0.72, 0, 1, duration: 0.62)
    }

    static func staggeredEntry(index: Int, prefersReducedMotion: Bool) -> Animation {
        if prefersReducedMotion {
            return .easeOut(duration: 0.16)
        }
        let clampedIndex = max(0, min(index, 5))
        let delay = Double(clampedIndex) * 0.03
        return .easeOut(duration: 0.35).delay(delay)
    }
}

enum Haptics {
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func softImpactIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        softGenerator.prepare()
        softGenerator.impactOccurred(intensity: 0.8)
    }

    static func selectionIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    static func successIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
}

enum PerformanceProfile {
    private static let lowMemoryThresholdBytes: UInt64 = 6_000_000_000

    static var prefersConservativeVisuals: Bool {
        isSimulator || ProcessInfo.processInfo.isLowPowerModeEnabled || isLowMemoryClass || isThermallyConstrained
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static var isLowMemoryClass: Bool {
        ProcessInfo.processInfo.physicalMemory <= lowMemoryThresholdBytes
    }

    private static var isThermallyConstrained: Bool {
        ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
    }
}

enum LaunchMetrics {
    /// Use wall-clock time instead of `ProcessInfo.processInfo.systemUptime` to avoid
    /// "required reason" API declarations for App Store privacy manifests.
    private static let launchDate = Date()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "startup"
    )
    private static let breadcrumbStorageKey = "launch.metrics.breadcrumbs.v1"
    private static let maxBreadcrumbCount = 80
    private static let breadcrumbQueue = DispatchQueue(label: "com.arrivaluk.launch-metrics")
    private static var breadcrumbCache: [String] = {
        guard let persisted = UserDefaults.standard.array(forKey: breadcrumbStorageKey) as? [String] else {
            return []
        }
        if persisted.count <= maxBreadcrumbCount {
            return persisted
        }
        return Array(persisted.suffix(maxBreadcrumbCount))
    }()
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func mark(event: String) {
        let elapsed = Date().timeIntervalSince(launchDate)
        let timestamp = timestampFormatter.string(from: Date())
        let breadcrumb = "\(timestamp) | +\(String(format: "%.3f", elapsed))s | \(event)"
        recordBreadcrumb(breadcrumb)

        #if DEBUG
        logger.debug("\(event, privacy: .public) +\(elapsed, format: .fixed(precision: 3))s")
        #endif
    }

    static func markStartupBudget(
        milestone: String,
        warningThresholdSeconds: TimeInterval
    ) {
        let elapsed = Date().timeIntervalSince(launchDate)
        if elapsed > warningThresholdSeconds {
            mark(event: "startup_budget_exceeded_\(milestone)_\(String(format: "%.2f", elapsed))s")
            #if DEBUG
            logger.error(
                "startup budget exceeded at \(milestone, privacy: .public): \(elapsed, format: .fixed(precision: 3))s"
            )
            #endif
            return
        }

        #if DEBUG
        logger.debug(
            "startup budget met at \(milestone, privacy: .public): \(elapsed, format: .fixed(precision: 3))s"
        )
        #endif
    }

    static func recentBreadcrumbs() -> [String] {
        breadcrumbQueue.sync {
            breadcrumbCache
        }
    }

    static func clearBreadcrumbs() {
        breadcrumbQueue.sync {
            breadcrumbCache.removeAll(keepingCapacity: true)
            UserDefaults.standard.removeObject(forKey: breadcrumbStorageKey)
        }
    }

    private static func recordBreadcrumb(_ breadcrumb: String) {
        breadcrumbQueue.sync {
            breadcrumbCache.append(breadcrumb)
            if breadcrumbCache.count > maxBreadcrumbCount {
                breadcrumbCache.removeFirst(breadcrumbCache.count - maxBreadcrumbCount)
            }
            UserDefaults.standard.set(breadcrumbCache, forKey: breadcrumbStorageKey)
        }
    }
}
