import SwiftUI

struct DisplayTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.display)
            .foregroundColor(AppTheme.Colors.textPrimary)
    }
}

struct SubtitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTheme.Typography.subtitle)
            .foregroundColor(AppTheme.Colors.textSecondary)
    }
}

extension View {
    func textStyleDisplay() -> some View {
        modifier(DisplayTextStyle())
    }

    func textStyleSubtitle() -> some View {
        modifier(SubtitleTextStyle())
    }
}

extension AppTheme {
    enum Typography {
        static let display: Font = .system(.title2, design: .default, weight: .semibold)
        static let subtitle: Font = .system(.subheadline, design: .default, weight: .medium)
        static let actionIcon: Font = .system(size: AppTheme.Layout.actionIconSize, weight: .medium)
    }
}
