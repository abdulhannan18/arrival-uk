import Foundation
import SwiftUI
import UIKit

struct SwipeableHeroStack: View {
    @State private var offset: CGSize = .zero
    @State private var predictedUrgencyScore = 0.0
    @Environment(TaskEngine.self) private var engine
    @Environment(\.layoutDirection) private var layoutDirection

    let isLowPowerModeEnabled: Bool
    let onOpenTask: (AppTask) -> Void
    let onCompleteTask: (AppTask) -> Void

    private var swipeThreshold: CGFloat {
        CGFloat(engine.phase3Config.swipeThreshold)
    }

    private var springDamping: CGFloat {
        CGFloat(engine.phase3Config.springDamping)
    }

    private var criticalUrgencyThreshold: Double {
        engine.phase3Config.criticalUrgencyThreshold
    }

    private var completionSwipeDirection: HorizontalSwipeDirection {
        RegionRuntime.completionSwipeDirection(forLayoutDirectionRTL: layoutDirection == .rightToLeft)
    }

    private var completionSwipeSign: CGFloat {
        completionSwipeDirection == .leftToRight ? 1 : -1
    }

    private var backgroundCardIndex: Int? {
        let configuredLimit = max(engine.phase3Config.heroCardLimit, 1)
        guard engine.survivalQueue.count > configuredLimit else { return nil }
        return configuredLimit
    }

    private var dragProgress: CGFloat {
        min(abs(offset.width) / max(swipeThreshold, 1), 1)
    }

    private var frontCardOpacity: CGFloat {
        max(0.7, 1 - (dragProgress * 0.35))
    }

    var body: some View {
        ZStack {
            if let backgroundCardIndex {
                HeroCardView(
                    task: engine.survivalQueue[backgroundCardIndex],
                    urgencyScore: 0,
                    criticalThreshold: criticalUrgencyThreshold
                )
                    .scaleEffect(AppTheme.Layout.heroPeekScale)
                    .offset(y: AppTheme.Layout.heroPeekYOffset)
                    .opacity(AppTheme.Layout.heroPeekOpacity)
                    .blur(radius: isLowPowerModeEnabled ? .zero : AppTheme.Layout.heroPeekBlurRadius)
                    .allowsHitTesting(false)
            }

            if engine.phase3Config.heroCardLimit == 0 {
                HeroFeatureDisabledCard()
            } else if let currentTask = engine.survivalQueue.first {
                HeroCardView(
                    task: currentTask,
                    urgencyScore: predictedUrgencyScore,
                    criticalThreshold: criticalUrgencyThreshold
                )
                    .opacity(frontCardOpacity)
                    .offset(
                        x: offset.width,
                        y: offset.height * AppTheme.Layout.heroVerticalDragFactor
                    )
                    .rotationEffect(.degrees(Double(offset.width / AppTheme.Layout.heroRotationDivisor)))
                    .onTapGesture {
                        onOpenTask(currentTask)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                                PerformanceMonitor.shared.recordHeroSwipeFrame(translation: gesture.translation)
                            }
                            .onEnded { _ in
                                let directedDistance = offset.width * completionSwipeSign
                                if directedDistance > swipeThreshold {
                                    handleTaskCompletion(currentTask)
                                } else {
                                    withAnimation(
                                        isLowPowerModeEnabled
                                            ? .easeOut(duration: 0.14)
                                            : .interactiveSpring(response: 0.3, dampingFraction: springDamping)
                                    ) {
                                        offset = .zero
                                    }
                                    PerformanceMonitor.shared.endHeroSwipe(didCommit: false)
                                }
                            }
                    )
            } else {
                HeroEmptyStateCard()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .task(id: "\(engine.survivalQueue.first?.id ?? "none")-\(criticalUrgencyThreshold)") {
            await refreshUrgencyPredictionIfNeeded()
        }
    }

    private func handleTaskCompletion(_ task: AppTask) {
        let dismissDirection: CGFloat = completionSwipeSign
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        if !isLowPowerModeEnabled {
            haptic.prepare()
        }

        withAnimation(
            isLowPowerModeEnabled
                ? .easeOut(duration: 0.16)
                : .interactiveSpring(response: 0.28, dampingFraction: springDamping)
        ) {
            offset = CGSize(
                width: dismissDirection * AppTheme.Layout.heroDismissTravelDistance,
                height: offset.height * AppTheme.Layout.heroVerticalDragFactor
            )
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: AppTheme.Layout.heroPopDelayNanos)
            guard !Task.isCancelled else { return }

            if !isLowPowerModeEnabled {
                haptic.impactOccurred()
            }

            withAnimation(
                isLowPowerModeEnabled
                    ? .easeOut(duration: 0.18)
                    : .spring(response: 0.5, dampingFraction: springDamping)
            ) {
                engine.completeTopTask()
            }
            onCompleteTask(task)
            offset = .zero
            PerformanceMonitor.shared.endHeroSwipe(didCommit: true)
        }
    }

    @MainActor
    private func refreshUrgencyPredictionIfNeeded() async {
        guard let currentTask = engine.survivalQueue.first else {
            predictedUrgencyScore = 0
            return
        }

        let profileStore = StudentProfileStore.shared
        let context = TaskUrgencyContext.liveContext(
            categories: ContentStore.shared.categories,
            arrivalDate: profileStore.arrivalDate,
            university: profileStore.selectedUniversity,
            city: profileStore.city
        )
        let score = TaskUrgencyPredictor.shared.predictUrgencyScore(for: currentTask, context: context)
        predictedUrgencyScore = score

        guard score >= criticalUrgencyThreshold else { return }

        TelemetryStore.shared.record(
            name: "phase10_critical_urgency_detected",
            level: .warning,
            properties: [
                "taskID": currentTask.taskID,
                "score": String(format: "%.2f", score)
            ]
        )
        await NotificationManager.shared.scheduleCriticalUrgencyAlert(task: currentTask, score: score)
    }
}

private struct HeroCardView: View {
    let task: AppTask
    let urgencyScore: Double
    let criticalThreshold: Double
    @State private var isHovered = false

    private var isCritical: Bool {
        urgencyScore >= criticalThreshold
    }

    private var priorityColor: Color {
        isCritical ? AppTheme.Colors.statusUrgent : AppTheme.Colors.actionPrimary
    }

    private var borderColor: Color {
        isCritical ? AppTheme.Colors.statusUrgent : AppTheme.Colors.textSecondary.opacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Image(systemName: task.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.actionPrimary)

                Text(task.categoryTitle.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(task.priority.label.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(priorityColor)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(priorityColor.opacity(0.12), in: Capsule())
            }

            Text(task.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            if let detail = task.detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }

            if isCritical {
                Label(
                    "Critical window (\(Int((urgencyScore * 100).rounded()))%)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.statusUrgent)
            }

            Spacer(minLength: .zero)

            Text("Swipe to complete")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(AppTheme.Layout.heroInternalPadding)
        .frame(maxWidth: .infinity, minHeight: AppTheme.Layout.heroCardMinHeight, alignment: .topLeading)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: isCritical ? 2 : 1)
        )
        .rotation3DEffect(
            .degrees(isHovered ? 4 : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.65
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .hoverEffect(.lift)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: Color.black.opacity(AppTheme.Layout.heroCardShadowOpacity),
            radius: AppTheme.Layout.heroCardShadowRadius,
            x: 0,
            y: AppTheme.Layout.heroCardShadowYOffset
        )
    }
}

private struct HeroEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("No survival tasks left")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("You are clear on Tier 1 priorities.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Layout.heroInternalPadding)
        .frame(maxWidth: .infinity, minHeight: AppTheme.Layout.heroCardMinHeight, alignment: .topLeading)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct HeroFeatureDisabledCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Priority engine paused")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("This feature is temporarily disabled by remote configuration.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(AppTheme.Layout.heroInternalPadding)
        .frame(maxWidth: .infinity, minHeight: AppTheme.Layout.heroCardMinHeight, alignment: .topLeading)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.heroCardCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MaintenanceTaskRow: View {
    let task: AppTask
    let onOpenTask: () -> Void
    let onCompleteTask: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: task.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(
                    width: AppTheme.Layout.maintenanceIconSize,
                    height: AppTheme.Layout.maintenanceIconSize
                )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(task.categoryTitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Button(action: onCompleteTask) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.actionPrimary)
                    .frame(
                        width: AppTheme.Layout.minimumTouchTarget,
                        height: AppTheme.Layout.minimumTouchTarget
                    )
            }
            .buttonStyle(AppFastButtonStyle())
            .accessibilityLabel("Complete task")
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.maintenanceRowCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.maintenanceRowCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.08), lineWidth: 1)
        )
        .hoverEffect(.lift)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenTask)
    }
}
