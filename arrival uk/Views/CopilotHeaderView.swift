import SwiftUI

struct CopilotHeaderView: View {
    var viewModel: HeaderViewModel
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void
    let isSettledMode: Bool
    let onUtilityTap: () -> Void
    let topSafeAreaInset: CGFloat
    var collaborationPresenceText: String?

    private var normalizedUserName: String {
        let trimmed = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? HomeLocalization.defaultFirstName : trimmed
    }

    private var topPadding: CGFloat {
        let adaptiveInset = min(max(topSafeAreaInset, .zero) * 0.35, AppTheme.Spacing.lg)
        return AppTheme.Spacing.lg + adaptiveInset
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("\(viewModel.greeting) \(normalizedUserName).")
                    .textStyleDisplay()
                    .lineLimit(1)
                    .minimumScaleFactor(AppTheme.Layout.greetingScaleFloor)
                    .accessibilityLabel("Greeting: \(viewModel.greeting) \(normalizedUserName)")

                Text(viewModel.copilotStatusText)
                    .textStyleSubtitle()
                    .lineLimit(1)
                    .minimumScaleFactor(AppTheme.Layout.statusScaleFloor)

                if let collaborationPresenceText,
                   !collaborationPresenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Circle()
                            .fill(Theme.successMain)
                            .frame(width: 8, height: 8)
                        Text(collaborationPresenceText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppTheme.Spacing.md) {
                Button(action: {
                    Haptics.selectionIfAllowed()
                    onSearchTap()
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(AppTheme.Typography.actionIcon)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(
                            width: AppTheme.Layout.minimumTouchTarget,
                            height: AppTheme.Layout.minimumTouchTarget
                        )
                        .background(AppTheme.Colors.bgSurface)
                        .clipShape(Circle())
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: AppTheme.Layout.actionShadowRadius,
                            x: 0,
                            y: AppTheme.Layout.actionShadowYOffset
                        )
                }
                .buttonStyle(AppFastButtonStyle())
                .accessibilityLabel(HomeLocalization.searchTasksLabel)

                Button(action: {
                    Haptics.selectionIfAllowed()
                    onProfileTap()
                }) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: AppTheme.Layout.minimumTouchTarget,
                            height: AppTheme.Layout.minimumTouchTarget
                        )
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(AppFastButtonStyle())
                .accessibilityLabel(HomeLocalization.openProfileLabel)

                Button(action: {
                    Haptics.selectionIfAllowed()
                    onUtilityTap()
                }) {
                    Image(systemName: isSettledMode ? "qrcode.viewfinder" : "plus")
                        .font(AppTheme.Typography.actionIcon)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(
                            width: AppTheme.Layout.minimumTouchTarget,
                            height: AppTheme.Layout.minimumTouchTarget
                        )
                        .background(AppTheme.Colors.bgSurface)
                        .clipShape(Circle())
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: AppTheme.Layout.actionShadowRadius,
                            x: 0,
                            y: AppTheme.Layout.actionShadowYOffset
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(AppFastButtonStyle())
                .accessibilityLabel(isSettledMode ? "Scan student discount QR code" : "Add task")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, topPadding)
        .padding(.bottom, AppTheme.Spacing.md)
        .background(AppTheme.Colors.bgPrimary)
    }
}

#Preview("Copilot Header 21:9", traits: .fixedLayout(width: 390, height: 820)) {
    CopilotHeaderView(
        viewModel: HeaderViewModel(
            userName: "Alex",
            arrivalDate: .now.addingTimeInterval(60 * 60 * 24 * 5),
            tasksCompletedPercentage: 36,
            currentDate: .now
        ),
        onSearchTap: {},
        onProfileTap: {},
        isSettledMode: false,
        onUtilityTap: {},
        topSafeAreaInset: 48,
        collaborationPresenceText: "Roommate active now"
    )
    .background(AppTheme.Colors.bgPrimary)
}
