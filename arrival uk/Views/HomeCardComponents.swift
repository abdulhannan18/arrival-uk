import SwiftUI

struct AppFastButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prefersReducedMotion: Bool {
        reduceMotion || PerformanceProfile.prefersConservativeVisuals
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                configuration.isPressed
                    ? Motion.pressDown(prefersReducedMotion: prefersReducedMotion)
                    : Motion.pressUp(prefersReducedMotion: prefersReducedMotion),
                value: configuration.isPressed
            )
    }
}

struct CategoryCard: View {
    @Binding var category: ChecklistCategory
    let completedTaskCount: Int
    let totalTaskCount: Int
    let isCategoryComplete: Bool
    let isPulsing: Bool
    let heroNamespace: Namespace.ID
    let heroID: String
    let isHeroSourceHidden: Bool
    let suppressShadow: Bool
    let isSuggestedStart: Bool
    let cardIndex: Int
    let tiltDegrees: Double
    let motionTilt: CGSize
    let onOpenCategory: () -> Void

    @State private var hasAppeared = false
    @AppStorage(StorageKey.homeHasLaunchedBefore.rawValue) private var hasLaunchedBefore = false

    private var displayTitle: String {
        HomeLocalization.categoryDisplayTitle(
            categoryID: category.id,
            fallbackTitle: category.title
        )
    }

    private var titleText: String {
        displayTitle
    }

    private var hintText: String {
        let explicitSubtitle = (category.subtitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitSubtitle.isEmpty {
            return explicitSubtitle
        }

        return category.resolvedSubtitle
    }

    private var visualStyle: CategoryVisualStyle {
        CategoryVisualHierarchy.getVisualStyle(category.visualPriority)
    }

    private var progress: Double {
        guard totalTaskCount > 0 else { return 0 }
        return min(max(Double(completedTaskCount) / Double(totalTaskCount), 0), 1)
    }

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    private var accentColor: Color {
        Theme.categoryBackground(for: category)
    }

    private var cardTextColor: Color {
        Theme.categoryText(for: category)
    }

    private var usesDarkForeground: Bool {
        Theme.categoryUsesDarkForeground(for: category)
    }

    private var badgeBackgroundColor: Color {
        Theme.categoryBadgeBackground(for: category)
    }

    private var badgeTextColor: Color {
        Theme.categoryBadgeText(for: category)
    }

    private var iconBackgroundColor: Color {
        cardTextColor.opacity(isCategoryComplete ? 0.10 : 0.14)
    }

    private var titleColor: Color {
        cardTextColor
    }

    private var hintColor: Color {
        cardTextColor.opacity(0.80)
    }

    private var progressLabelColor: Color {
        cardTextColor.opacity(0.82)
    }

    private var progressTrackColor: Color {
        cardTextColor.opacity(0.18)
    }

    private var cardBorderColor: Color {
        usesDarkForeground ? Theme.navy200.opacity(0.55) : Color.white.opacity(0.18)
    }

    private var actionSurfaceColor: Color {
        usesDarkForeground ? Theme.cream100.opacity(0.88) : Color.white.opacity(0.14)
    }

    private var actionBorderColor: Color {
        usesDarkForeground ? Theme.navy200.opacity(0.70) : Color.white.opacity(0.28)
    }

    private var actionTextColor: Color {
        usesDarkForeground ? Theme.navy900 : Theme.inverseText
    }

    private var shouldShowProgress: Bool {
        totalTaskCount > 0 && completedTaskCount > 0 && completedTaskCount < totalTaskCount
    }

    private var metaLine: String {
        var chunks: [String] = []
        if totalTaskCount == 0 {
            chunks.append("No tasks yet")
        } else if completedTaskCount == totalTaskCount {
            let taskWord = totalTaskCount == 1 ? "task" : "tasks"
            chunks.append("Completed \(totalTaskCount) \(taskWord)")
        } else {
            let taskWord = totalTaskCount == 1 ? "task" : "tasks"
            chunks.append("\(completedTaskCount)/\(totalTaskCount) \(taskWord)")
        }

        if let dueLabel = category.deadlineLabel {
            chunks.append("Due \(dueLabel)")
        }

        return chunks.joined(separator: " • ")
    }

    private var actionLabel: String {
        if totalTaskCount == 0 { return "Open Category" }
        if completedTaskCount == 0 { return "Start Category" }
        if completedTaskCount == totalTaskCount { return "Review Category" }
        return "Continue Category"
    }

    private var urgencyLabel: String {
        switch category.urgencyBand {
        case .immediate:
            return "Immediate"
        case .week1:
            return "Week 1"
        case .week2:
            return "Week 2"
        case .anytime:
            return "Anytime"
        case .completed:
            return "Done"
        }
    }

    private var shadowConfig: (color: Color, radius: CGFloat, y: CGFloat) {
        switch visualStyle.shadowLevel {
        case .none:
            return (.clear, 0, 0)
        case .subtle:
            return (Theme.shadowSoft, 2, 1)
        case .medium:
            return (Theme.shadowMedium, 8, 4)
        case .elevated:
            return (Theme.shadowCritical, 20, 12)
        }
    }

    var body: some View {
        Button {
            HapticService.shared.medium()
            onOpenCategory()
        } label: {
            VStack(alignment: .leading, spacing: max(10, visualStyle.cardPadding * 0.34)) {
                HStack(spacing: Theme.spaceS) {
                    Text(urgencyLabel.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(badgeTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(badgeBackgroundColor)
                        )

                    Spacer()

                    if isCategoryComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(cardTextColor)
                            .accessibilityHidden(true)
                    }
                }

                HStack(spacing: Theme.spaceS) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(iconBackgroundColor)
                            .matchedGeometryEffect(id: "category-hero-shape-\(heroID)", in: heroNamespace)

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(cardTextColor.opacity(0.16), lineWidth: 1)

                        Image(systemName: category.icon)
                            .font(.system(size: max(20, visualStyle.iconSize * 0.36), weight: .semibold))
                            .foregroundStyle(cardTextColor)
                    }
                    .frame(width: visualStyle.iconSize, height: visualStyle.iconSize)
                    .matchedGeometryEffect(id: "category-icon-\(heroID)", in: heroNamespace)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(titleText)
                            .font(.system(size: visualStyle.titleFontSize, weight: visualStyle.titleWeight))
                            .tracking(visualStyle.titleTracking)
                            .foregroundStyle(titleColor)
                            .lineLimit(1)
                            .matchedGeometryEffect(id: "category-title-\(heroID)", in: heroNamespace)

                        if !hintText.isEmpty {
                            Text(hintText)
                                .font(.system(size: visualStyle.subtitleFontSize, weight: visualStyle.subtitleWeight))
                                .foregroundStyle(hintColor.opacity(visualStyle.subtitleOpacity / 0.80))
                                .lineLimit(1)
                                .matchedGeometryEffect(id: "category-subtitle-\(heroID)", in: heroNamespace)
                        }
                    }

                    Spacer()
                }

                Text(metaLine)
                    .font(.system(size: visualStyle.metaFontSize, weight: .semibold))
                    .foregroundStyle(progressLabelColor)
                    .lineLimit(1)

                if shouldShowProgress {
                    HStack(alignment: .center, spacing: 10) {
                        CategoryCardProgressBar(
                            progress: progress,
                            fillColor: cardTextColor,
                            trackColor: progressTrackColor
                        )
                        .frame(height: 7)
                        .clipShape(Capsule(style: .continuous))

                        Text("\(progressPercent)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(progressLabelColor)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(actionTextColor)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(actionTextColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(actionSurfaceColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(actionBorderColor, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: visualStyle.minHeight, alignment: .topLeading)
            .padding(visualStyle.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                    .fill(accentColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                    .stroke(isPulsing ? Color.white.opacity(0.32) : cardBorderColor, lineWidth: 1)
            )
            .shadow(
                color: suppressShadow ? .clear : (isPulsing ? accentColor.opacity(0.28) : shadowConfig.color.opacity(0.75)),
                radius: isPulsing ? max(18, shadowConfig.radius) : shadowConfig.radius,
                x: 0,
                y: isPulsing ? max(10, shadowConfig.y) : shadowConfig.y
            )
            .opacity(isCategoryComplete ? 0.84 : 1)
            .scaleEffect(x: hasLaunchedBefore || hasAppeared ? 1.0 : 0.96, y: 1.0, anchor: .center)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78).delay(Double(cardIndex) * 0.05),
                value: hasAppeared
            )
            .matchedGeometryEffect(id: "category-card-\(heroID)", in: heroNamespace)
            .contentShape(RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
        .opacity(isHeroSourceHidden ? 0 : 1)
        .onAppear {
            HapticService.shared.prepare()

            guard !hasAppeared else { return }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(cardIndex) * ArrivalTokens.Animation.cardStagger
            ) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    hasAppeared = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            HomeLocalization.categoryAccessibilityLabel(
                title: displayTitle,
                completedCount: completedTaskCount,
                totalCount: totalTaskCount
            )
        )
        .accessibilityHint(isSuggestedStart ? HomeLocalization.startHereHint : HomeLocalization.categoryCardHint)
    }

    private func rgba(_ red: Double, _ green: Double, _ blue: Double, _ opacity: Double) -> Color {
        Color(
            .sRGB,
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            opacity: opacity
        )
    }

    private func formattedTitle(from rawTitle: String) -> String {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count > 14 else { return title }

        if title.contains(" & ") {
            return title.replacingOccurrences(of: " & ", with: "\n")
        }

        // Balance long titles onto two lines around midpoint.
        guard title.count > 21 else { return title }
        let words = title.split(separator: " ")
        guard words.count >= 3 else { return title }

        let target = max(8, title.count / 2)
        var running = 0
        for (index, word) in words.dropLast().enumerated() {
            running += word.count
            if running >= target {
                let first = words.prefix(index + 1).joined(separator: " ")
                let second = words.suffix(words.count - (index + 1)).joined(separator: " ")
                guard !first.isEmpty, !second.isEmpty else { return title }
                return "\(first)\n\(second)"
            }
            running += 1
        }

        return title
    }
}

private struct CategoryCardGlossOverlay: View {
    let cornerRadius: CGFloat
    let startColor: Color

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [startColor, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.size.height * 0.48)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

private struct CategoryCardEdgeHighlight: View {
    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = proxy.size.width * 0.14
            Rectangle()
                .fill(Color.white.opacity(0.65))
                .frame(height: 1)
                .padding(.horizontal, horizontalInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct CategoryCardProgressBar: View {
    let progress: Double
    let fillColor: Color
    let trackColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(trackColor)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(fillColor)
                    .frame(width: proxy.size.width * progress)
                    .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.8), value: progress)
            }
        }
    }
}

private struct CategoryDoneRing: View {
    var body: some View {
        Circle()
            .fill(Color(.sRGB, red: 22 / 255, green: 163 / 255, blue: 74 / 255, opacity: 1))
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .shadow(
                color: Color(.sRGB, red: 22 / 255, green: 163 / 255, blue: 74 / 255, opacity: 0.40),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}
