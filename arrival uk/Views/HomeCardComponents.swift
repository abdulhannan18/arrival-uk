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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var orbHoverLift = false
    @AppStorage(StorageKey.homeHasLaunchedBefore.rawValue) private var hasLaunchedBefore = false

    private let cornerRadius: CGFloat = 22
    private let cardHeight: CGFloat = 172

    private var displayTitle: String {
        HomeLocalization.categoryDisplayTitle(
            categoryID: category.id,
            fallbackTitle: category.title
        )
    }

    private var titleText: String {
        formattedTitle(from: displayTitle)
    }

    private var hintText: String {
        if isSuggestedStart {
            return "Start here"
        }

        let explicitSubtitle = (category.subtitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitSubtitle.isEmpty {
            return explicitSubtitle
        }

        return category.resolvedDefaultSubtitle
    }

    private var progress: Double {
        guard totalTaskCount > 0 else { return 0 }
        return min(max(Double(completedTaskCount) / Double(totalTaskCount), 0), 1)
    }

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    private var orbTheme: CategoryOrbTheme {
        CategoryColorSystem.orbTheme(for: category, index: cardIndex)
    }

    private var surfaceColor: Color {
        if colorScheme == .dark {
            return rgba(22, 22, 35, 0.85)
        }
        return rgba(255, 255, 255, 0.78)
    }

    private var borderColor: Color {
        if colorScheme == .dark {
            return rgba(255, 255, 255, 0.08)
        }
        return rgba(255, 255, 255, 0.95)
    }

    private var glossStartColor: Color {
        if colorScheme == .dark {
            return rgba(255, 255, 255, 0.06)
        }
        return rgba(255, 255, 255, 0.24)
    }

    private var titleColor: Color {
        if colorScheme == .dark {
            return Color.white
        }
        return rgba(10, 10, 18, 1)
    }

    private var hintColor: Color {
        if colorScheme == .dark {
            return rgba(255, 255, 255, 0.40)
        }
        return rgba(10, 10, 18, 0.36)
    }

    private var progressLabelColor: Color {
        if colorScheme == .dark {
            return rgba(255, 255, 255, 0.28)
        }
        return rgba(10, 10, 18, 0.30)
    }

    private var progressTrackColor: Color {
        if colorScheme == .dark {
            return rgba(255, 255, 255, 0.10)
        }
        return rgba(0, 0, 0, 0.09)
    }

    private var shadowColorPrimary: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.50)
        }
        return Color.black.opacity(0.09)
    }

    private var shadowColorSecondary: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.30)
        }
        return Color.black.opacity(0.05)
    }

    private var prefersReducedMotion: Bool {
        reduceMotion || PerformanceProfile.prefersConservativeVisuals
    }

    var body: some View {
        Button {
            HapticService.shared.medium()
            onOpenCategory()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surfaceColor)

                Circle()
                    .fill(orbTheme.orbGradient)
                    .frame(width: 220, height: 220)
                    .offset(x: orbHoverLift ? 44 : 50, y: orbHoverLift ? -55 : -50)
                    .scaleEffect(orbHoverLift ? 1.08 : 1.0)
                    .matchedGeometryEffect(id: "category-hero-shape-\(heroID)", in: heroNamespace)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                CategoryCardGlossOverlay(
                    cornerRadius: cornerRadius,
                    startColor: glossStartColor
                )
                .allowsHitTesting(false)

                CategoryCardEdgeHighlight()
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    Text(hintText)
                        .font(ArrivalTypography.figtree(size: 11, weight: .medium))
                        .foregroundStyle(hintColor)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "category-subtitle-\(heroID)", in: heroNamespace)
                        .padding(.top, 18)

                    Spacer(minLength: 0)

                    Text(titleText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                        .padding(.bottom, 12)
                        .matchedGeometryEffect(id: "category-title-\(heroID)", in: heroNamespace)

                    HStack(alignment: .center, spacing: 10) {
                        CategoryCardProgressBar(
                            progress: progress,
                            fillColor: orbTheme.fillAccent,
                            trackColor: progressTrackColor
                        )
                        .frame(height: 1.5)

                        Text("\(progressPercent)%")
                            .font(ArrivalTypography.figtree(size: 9.5, weight: .semibold))
                            .foregroundStyle(progressLabelColor)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
                .padding(.trailing, 78)
                .offset(x: motionTilt.width, y: motionTilt.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(4)

                Color.clear
                    .frame(width: 1, height: 1)
                    .matchedGeometryEffect(id: "category-icon-\(heroID)", in: heroNamespace)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if isCategoryComplete {
                    CategoryDoneRing()
                        .padding(.trailing, 14)
                        .padding(.bottom, 14)
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: suppressShadow ? .clear : shadowColorPrimary, radius: 16, x: 0, y: 10)
            .shadow(color: suppressShadow ? .clear : shadowColorSecondary, radius: 8, x: 0, y: 2)
            .opacity(isCategoryComplete ? 0.62 : 1)
            .scaleEffect(x: hasLaunchedBefore || hasAppeared ? 1.0 : 0.85, y: 1.0, anchor: .center)
            .rotation3DEffect(
                .degrees(tiltDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.5
            )
            .animation(
                .spring(response: 0.5, dampingFraction: 0.75).delay(Double(cardIndex) * 0.06),
                value: hasAppeared
            )
            .matchedGeometryEffect(id: "category-card-\(heroID)", in: heroNamespace)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .drawingGroup()
        }
        .buttonStyle(CardButtonStyle())
        .opacity(isHeroSourceHidden ? 0 : 1)
        .onAppear {
            HapticService.shared.prepare()

            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(cardIndex) * ArrivalTokens.Animation.cardStagger
            ) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    hasAppeared = true
                }
            }

            updateOrbHoverState(for: isPulsing)
        }
        .onChange(of: isPulsing) { _, nextValue in
            updateOrbHoverState(for: nextValue)
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

    private func updateOrbHoverState(for shouldHover: Bool) {
        if !shouldHover {
            withAnimation(.easeOut(duration: prefersReducedMotion ? 0.12 : 0.22)) {
                orbHoverLift = false
            }
            return
        }

        withAnimation(
            .timingCurve(0.16, 1, 0.3, 1, duration: prefersReducedMotion ? 0.14 : 0.55)
                .repeatForever(autoreverses: true)
        ) {
            orbHoverLift = true
        }
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
