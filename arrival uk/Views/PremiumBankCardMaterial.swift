import SwiftUI

/// Premium frosted bank-card shell for homepage category rows.
/// Keep this component presentation-only so all categories can share it.
struct PremiumBankCardMaterial<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let material: AppCategory.PremiumBankCardMaterial
    let isPressed: Bool
    let showsShadow: Bool
    let contentPadding: CGFloat
    private let content: Content

    init(
        material: AppCategory.PremiumBankCardMaterial = .standard,
        isPressed: Bool = false,
        showsShadow: Bool = true,
        contentPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.material = material
        self.isPressed = isPressed
        self.showsShadow = showsShadow
        self.contentPadding = contentPadding
        self.content = content()
    }

    private var cornerRadius: CGFloat { 22 }

    private var ivoryOverlayColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color.white.opacity(0.68)
    }

    private var metallicStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.72 : 0.85),
                Color.white.opacity(colorScheme == .dark ? 0.32 : 0.40),
                Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerBevelColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.42 : 0.75)
    }

    var body: some View {
        content
            .padding(contentPadding)
            .background(backgroundLayers)
            .shadow(color: .black.opacity(showsShadow ? (colorScheme == .dark ? 0.24 : 0.12) : 0), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(showsShadow ? (colorScheme == .dark ? 0.16 : 0.06) : 0), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(innerBevelColor, lineWidth: 1)
                    .blur(radius: 1)
            )
            .offset(y: isPressed ? 2 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPressed)
            .compositingGroup()
    }

    @ViewBuilder
    private var backgroundLayers: some View {
        switch material {
        case .standard:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(ivoryOverlayColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(metallicStrokeGradient, lineWidth: 1.5)
                )
        }
    }
}
