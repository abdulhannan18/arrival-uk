import Foundation
import SwiftUI
import UIKit
import AVFoundation

struct HorizonPrioritySection: View {
    @Environment(TaskEngine.self) private var engine
    @Environment(ConfigService.self) private var configService

    let isSettledMode: Bool
    let isLowPowerModeEnabled: Bool
    let onOpenTask: (AppTask) -> Void
    let onCompleteHeroTask: (AppTask) -> Void
    let onCompleteMaintenanceTask: (AppTask) -> Void
    let onOpenDiscoveryLink: (URL) -> Void
    let onLaunchMarketplaceService: (MarketplaceProviderDescriptor, String) -> Void
    @Namespace private var discoveryPivotNamespace
    @State private var discoveryItems: [DiscoveryItem] = DiscoveryItem.defaultItems
    @State private var isDiscoveryLoading = false
    @State private var hasLoadedDiscovery = false
    @State private var discoveryLastUpdatedAt: Date?
    @State private var discoveryStatusMessage: String?
    @State private var discoveryQuery = ""
    @State private var sharedBoardStore = SharedDiscoveryBoardStore.shared
    @State private var sharedTransferItemID: String?
    @Namespace private var sharedBoardNamespace

    private var hasSurvival: Bool {
        engine.phase3Config.heroCardLimit > 0 && !engine.survivalQueue.isEmpty
    }

    private var hasMaintenance: Bool {
        !engine.maintenanceTasks.isEmpty
    }

    private var marketplaceProviders: [MarketplaceProviderDescriptor] {
        configService.effectiveMarketplaceProviders
    }

    private var filteredDiscoveryItems: [DiscoveryItem] {
        let normalizedQuery = discoveryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return discoveryItems
        }

        let rankedIDs = DiscoverySemanticSearch.rank(
            candidates: discoveryItems.map { item in
                DiscoverySemanticCandidate(
                    id: item.id,
                    title: item.title,
                    subtitle: item.subtitle
                )
            },
            query: normalizedQuery
        )
        guard !rankedIDs.isEmpty else { return [] }

        let rank = Dictionary(
            uniqueKeysWithValues: rankedIDs.enumerated().map { index, id in
                (id, index)
            }
        )
        return discoveryItems
            .filter { rank[$0.id] != nil }
            .sorted { lhs, rhs in
                let lhsRank = rank[lhs.id] ?? .max
                let rhsRank = rank[rhs.id] ?? .max
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.id < rhs.id
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if isSettledMode {
                discoveryGuideSection
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .zIndex(3)
            } else {
                if hasSurvival {
                    Text("SURVIVAL PRIORITIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    SwipeableHeroStack(
                        isLowPowerModeEnabled: isLowPowerModeEnabled,
                        onOpenTask: onOpenTask,
                        onCompleteTask: onCompleteHeroTask
                    )
                    .zIndex(2)
                }

                if hasMaintenance {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("MAINTENANCE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .padding(.horizontal, AppTheme.Spacing.md)

                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(engine.maintenanceTasks) { task in
                                MaintenanceTaskRow(
                                    task: task,
                                    onOpenTask: { onOpenTask(task) },
                                    onCompleteTask: { onCompleteMaintenanceTask(task) }
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                    .padding(.top, hasSurvival ? AppTheme.Spacing.xl : .zero)
                    .zIndex(1)
                }

                lockedDiscoveryFooter
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, (hasSurvival || hasMaintenance) ? AppTheme.Spacing.xl : .zero)
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .animation(
            isLowPowerModeEnabled
                ? .easeOut(duration: 0.20)
                : .spring(response: 0.55, dampingFraction: 0.84),
            value: isSettledMode
        )
        .task(id: isSettledMode) {
            guard isSettledMode else { return }
            await refreshDiscoveryItemsIfNeeded()
        }
    }

    private var lockedDiscoveryFooter: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("CITY GUIDE LOCKED")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer(minLength: AppTheme.Spacing.sm)
            }

            Text("Finish Survival priorities to unlock student discounts, local tips, and nightlife discovery.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(DiscoveryItem.defaultItems.prefix(3)) { item in
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 10, weight: .bold))
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.bgPrimary, in: Capsule())
                }
            }
            .blur(radius: isLowPowerModeEnabled ? .zero : AppTheme.Layout.discoveryLockedPreviewBlur)
            .allowsHitTesting(false)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                style: .continuous
            )
            .fill(AppTheme.Colors.bgSurface)
            .matchedGeometryEffect(id: "discovery-pivot-surface", in: discoveryPivotNamespace)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.10), lineWidth: 1)
        )
    }

    private var discoveryGuideSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Text("CITY GUIDE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer(minLength: AppTheme.Spacing.sm)

                Label("Settled", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.actionPrimary)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.actionPrimary.opacity(0.12), in: Capsule())
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("Search by intent: cheap groceries, late buses...", text: $discoveryQuery)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if !discoveryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        discoveryQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.bgPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            SharedDiscoveryBoardStrip(
                items: sharedBoardStore.items,
                transferItemID: sharedTransferItemID,
                transferNamespace: sharedBoardNamespace
            )

            if !marketplaceProviders.isEmpty {
                MarketplaceProviderStrip(
                    providers: marketplaceProviders,
                    onLaunch: { provider in
                        onLaunchMarketplaceService(provider, "discovery_grid")
                    }
                )
            }

            if isDiscoveryLoading && !hasLoadedDiscovery {
                DiscoverySkeletonGrid()
            } else {
                if filteredDiscoveryItems.isEmpty &&
                    !discoveryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No matches yet. Try broader wording like supermarkets, discounts, or transport.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.vertical, AppTheme.Spacing.sm)
                } else {
                    DiscoveryGrid(
                        items: filteredDiscoveryItems,
                        onOpenItem: { item in
                            if let provider = providerForDiscoveryItem(item) {
                                onLaunchMarketplaceService(provider, "discovery_tap")
                                return
                            }
                            if let destinationURL = item.destinationURL {
                                onOpenDiscoveryLink(destinationURL)
                            } else {
                                Haptics.selectionIfAllowed()
                            }
                        },
                        onShareItem: { item in
                            shareDiscoveryItem(item)
                        },
                        transferItemID: sharedTransferItemID,
                        transferNamespace: sharedBoardNamespace
                    )
                }
            }

            if let discoveryStatusMessage {
                Text(discoveryStatusMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else if let discoveryLastUpdatedAt {
                Text("Updated \(UKLocaleFormat.mediumDateString(discoveryLastUpdatedAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else if isDiscoveryLoading {
                Text("Loading perks...")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                style: .continuous
            )
            .fill(AppTheme.Colors.bgSurface)
            .matchedGeometryEffect(id: "discovery-pivot-surface", in: discoveryPivotNamespace)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                style: .continuous
            )
            .stroke(AppTheme.Colors.textSecondary.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    @MainActor
    private func refreshDiscoveryItemsIfNeeded(force: Bool = false) async {
        guard isSettledMode else { return }
        guard !isDiscoveryLoading else { return }
        guard force || !hasLoadedDiscovery else { return }

        isDiscoveryLoading = true
        defer { isDiscoveryLoading = false }

        let fetchedItems = await DiscoveryContentEngine.fetchPerks()
        withAnimation(
            isLowPowerModeEnabled
                ? .easeOut(duration: 0.20)
                : .spring(response: 0.5, dampingFraction: 0.85)
        ) {
            if !fetchedItems.isEmpty {
                discoveryItems = fetchedItems
                discoveryStatusMessage = nil
            } else {
                discoveryItems = DiscoveryItem.defaultItems
                discoveryStatusMessage = "Using offline discovery picks."
            }
            discoveryLastUpdatedAt = Date()
            hasLoadedDiscovery = true
        }
    }

    @MainActor
    private func shareDiscoveryItem(_ item: DiscoveryItem) {
        let actorName = StudentProfileStore.shared.preferredFirstName ?? "You"
        sharedBoardStore.addItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            symbolName: item.symbolName,
            addedBy: actorName
        )

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            sharedTransferItemID = item.id
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                sharedTransferItemID = nil
            }
        }

        TelemetryStore.shared.record(
            name: "phase13_shared_discovery_saved",
            level: .info,
            properties: [
                "itemID": item.id
            ]
        )
    }

    private func providerForDiscoveryItem(_ item: DiscoveryItem) -> MarketplaceProviderDescriptor? {
        let normalizedID = item.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return marketplaceProviders.first(where: { provider in
            let providerID = provider.normalizedProviderID
            if providerID == normalizedID { return true }
            if let tag = provider.discoveryTag?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !tag.isEmpty,
               (normalizedID.contains(tag) || normalizedTitle.contains(tag)) {
                return true
            }
            switch provider.serviceType {
            case .sim:
                return normalizedID.contains("sim") || normalizedTitle.contains("sim")
            case .banking:
                return normalizedID.contains("bank") || normalizedTitle.contains("bank")
            case .housing:
                return normalizedID.contains("house") || normalizedTitle.contains("housing") || normalizedID.contains("rent")
            case .unknown:
                return false
            }
        })
    }
}

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

private struct MaintenanceTaskRow: View {
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

private struct DiscoveryItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let accent: Color
    let imageURL: URL?
    let destinationURL: URL?

    static let defaultItems: [DiscoveryItem] = [
        DiscoveryItem(
            id: "student-discounts",
            title: "Student Discounts",
            subtitle: "Top offers near campus",
            symbolName: "ticket.fill",
            accent: Theme.sage600,
            imageURL: nil,
            destinationURL: URL(string: "https://www.totum.com")
        ),
        DiscoveryItem(
            id: "social-mixers",
            title: "Social Mixers",
            subtitle: "Events this week",
            symbolName: "person.3.fill",
            accent: Theme.brandPrimary,
            imageURL: nil,
            destinationURL: URL(string: "https://www.meetup.com/find/?source=EVENTS&keywords=students")
        ),
        DiscoveryItem(
            id: "local-tips",
            title: "Local Tips",
            subtitle: "City shortcuts",
            symbolName: "mappin.and.ellipse",
            accent: Theme.warmOrange500,
            imageURL: nil,
            destinationURL: URL(string: "https://www.visitlondon.com")
        ),
        DiscoveryItem(
            id: "nightlife",
            title: "Nightlife",
            subtitle: "Student-friendly spots",
            symbolName: "moon.stars.fill",
            accent: Theme.brandSecondary,
            imageURL: nil,
            destinationURL: URL(string: "https://www.timeout.com/london/nightlife")
        )
    ]
}

private struct DiscoveryGrid: View {
    let items: [DiscoveryItem]
    let onOpenItem: (DiscoveryItem) -> Void
    let onShareItem: (DiscoveryItem) -> Void
    let transferItemID: String?
    let transferNamespace: Namespace.ID
    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
            ForEach(items) { item in
                Button {
                    onOpenItem(item)
                } label: {
                    DiscoveryCard(
                        perk: item,
                        transferNamespace: transferNamespace,
                        isTransferSource: transferItemID == item.id
                    )
                }
                .buttonStyle(AppFastButtonStyle())
                .contextMenu {
                    Button {
                        onShareItem(item)
                    } label: {
                        Label("Add to Shared House Board", systemImage: "person.2.crop.square.stack")
                    }
                }
                .accessibilityLabel(item.title)
            }
        }
    }
}

private struct DiscoveryCard: View {
    let perk: DiscoveryItem
    let transferNamespace: Namespace.ID
    let isTransferSource: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            CachedDiscoveryImage(url: perk.imageURL, accent: perk.accent)
            .frame(height: AppTheme.Layout.discoveryCardImageHeight)
            .clipped()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: perk.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(perk.accent)
                        .matchedGeometryEffect(
                            id: "shared-discovery-symbol-\(perk.id)",
                            in: transferNamespace,
                            isSource: isTransferSource
                        )
                    Text(perk.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text(perk.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: AppTheme.Layout.discoveryCardSize,
            maxHeight: AppTheme.Layout.discoveryCardSize
        )
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryTileCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryTileCornerRadius,
                style: .continuous
            )
            .stroke(perk.accent.opacity(0.12), lineWidth: 1)
        )
        .hoverEffect(.lift)
    }

}

private struct SharedDiscoveryBoardStrip: View {
    let items: [SharedDiscoveryBoardItem]
    let transferItemID: String?
    let transferNamespace: Namespace.ID

    private var headlineText: String {
        if let latest = items.first {
            return "Shared House Board • Latest by \(latest.addedBy)"
        }
        return "Shared House Board"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "person.2.crop.square.stack")
                    .font(.system(size: 12, weight: .semibold))
                Text(headlineText)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Spacer(minLength: AppTheme.Spacing.sm)
                Text("\(items.count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.actionPrimary.opacity(0.14), in: Capsule())
            }
            .foregroundStyle(AppTheme.Colors.textSecondary)

            if items.isEmpty {
                Text("Long-press a perk and add it here for your roommate.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(Array(items.prefix(6))) { item in
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: item.symbolName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .matchedGeometryEffect(
                                        id: "shared-discovery-symbol-\(item.id)",
                                        in: transferNamespace,
                                        isSource: transferItemID != item.id
                                    )
                                Text(item.title)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(AppTheme.Colors.bgSurface, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.bgPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MarketplaceProviderStrip: View {
    let providers: [MarketplaceProviderDescriptor]
    let onLaunch: (MarketplaceProviderDescriptor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Service Marketplace")
                    .font(.caption.weight(.bold))
                Spacer(minLength: AppTheme.Spacing.sm)
                Text("\(providers.count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.actionPrimary.opacity(0.12), in: Capsule())
            }
            .foregroundStyle(AppTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(providers) { provider in
                        Button {
                            onLaunch(provider)
                        } label: {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(provider.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(provider.ctaTitle)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.actionPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(AppFastButtonStyle())
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.bgPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CachedDiscoveryImage: View {
    enum Phase {
        case loading
        case success(UIImage)
        case failure
    }

    let url: URL?
    let accent: Color
    @State private var phase: Phase = .loading
    @State private var loadTask: Task<UIImage?, Never>?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                Rectangle()
                    .fill(AppTheme.Colors.bgPrimary)
                    .shimmer(active: true)
            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            case .failure:
                LinearGradient(
                    colors: [
                        accent.opacity(0.18),
                        AppTheme.Colors.bgPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .task(id: url) {
            await loadImageIfNeeded()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "https" else {
            phase = .failure
            return
        }

        if let cached = DiscoveryImageCache.shared.image(for: url) {
            phase = .success(cached)
            return
        }

        phase = .loading
        loadTask?.cancel()

        let task = Task(priority: .utility) { () -> UIImage? in
            do {
                let request = URLRequest(
                    url: url,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: AppConfig.requestTimeout
                )
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200 ... 299).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    return nil
                }
                return image
            } catch {
                return nil
            }
        }

        loadTask = task
        let image = await task.value
        guard !Task.isCancelled else { return }

        if let image {
            DiscoveryImageCache.shared.store(image, for: url)
            withAnimation(.easeInOut(duration: 0.24)) {
                phase = .success(image)
            }
        } else {
            phase = .failure
            TelemetryStore.shared.record(
                name: "discovery_image_fetch_failed",
                level: .warning,
                properties: [
                    "host": url.host ?? "unknown"
                ]
            )
        }
    }
}

private struct DiscoverySkeletonGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: .zero) {
                    Rectangle()
                        .fill(AppTheme.Colors.bgPrimary)
                        .frame(height: AppTheme.Layout.discoveryCardImageHeight)
                        .shimmer(active: true)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppTheme.Colors.bgPrimary)
                            .frame(height: 13)
                            .shimmer(active: true)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppTheme.Colors.bgPrimary)
                            .frame(height: 10)
                            .shimmer(active: true)
                    }
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: AppTheme.Layout.discoveryCardSize,
                    maxHeight: AppTheme.Layout.discoveryCardSize
                )
                .background(AppTheme.Colors.bgSurface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Layout.discoveryTileCornerRadius,
                        style: .continuous
                    )
                )
            }
        }
        .redacted(reason: .placeholder)
    }
}

private struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -AppTheme.Layout.discoveryShimmerTravel

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.34),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: width * 0.35)
                        .rotationEffect(.degrees(18))
                        .offset(x: phase)
                        .onAppear {
                            phase = -AppTheme.Layout.discoveryShimmerTravel
                            withAnimation(
                                .linear(duration: AppTheme.Layout.discoveryShimmerDuration)
                                .repeatForever(autoreverses: false)
                            ) {
                                phase = AppTheme.Layout.discoveryShimmerTravel
                            }
                        }
                    }
                    .clipped()
                }
            }
    }
}

private extension View {
    func shimmer(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

private enum DiscoveryContentEngine {
    static func fetchPerks() async -> [DiscoveryItem] {
        guard #available(iOS 17.0, *) else {
            return []
        }

        let endpoint = AppConfig.apiBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("discovery")
            .appendingPathComponent("perks")
            .absoluteString

        do {
            let response: DiscoveryPerksResponse = try await SecureHTTPClient.shared.request(endpoint: endpoint)
            let mapped = response.items.compactMap { item in
                DiscoveryItem.from(apiItem: item)
            }
            return mapped
        } catch {
            CrashReporter.record(error: error, context: "discovery_perks_fetch")
            return []
        }
    }
}

private struct DiscoveryPerksResponse: Decodable {
    let items: [DiscoveryPerkAPIItem]
}

private struct DiscoveryPerkAPIItem: Decodable {
    let id: String?
    let title: String?
    let name: String?
    let subtitle: String?
    let description: String?
    let symbol: String?
    let icon: String?
    let imageURLString: String?
    let accentHex: String?
    let accentColor: String?
    let destinationURLString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case subtitle
        case description
        case symbol
        case icon
        case imageURLString = "imageURL"
        case accentHex
        case accentColor
        case destinationURLString = "destinationURL"
    }
}

private extension DiscoveryItem {
    static func from(apiItem: DiscoveryPerkAPIItem) -> DiscoveryItem? {
        let resolvedTitle = (apiItem.title ?? apiItem.name)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolvedTitle, !resolvedTitle.isEmpty else { return nil }

        let normalizedID = (apiItem.id?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? apiItem.id!.trimmingCharacters(in: .whitespacesAndNewlines)
            : resolvedTitle.lowercased().replacingOccurrences(of: " ", with: "-")
        let resolvedSubtitle: String = {
            let subtitle = apiItem.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let subtitle, !subtitle.isEmpty { return subtitle }
            let description = apiItem.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let description, !description.isEmpty { return description }
            return "Verified student perk"
        }()
        let symbolName: String = {
            let symbol = apiItem.symbol?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let symbol, !symbol.isEmpty { return symbol }
            let icon = apiItem.icon?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let icon, !icon.isEmpty { return icon }
            return "sparkles"
        }()
        let imageURL: URL? = {
            guard let raw = apiItem.imageURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" else {
                return nil
            }
            return url
        }()

        let accentColor = resolvedAccentColor(from: apiItem.accentHex ?? apiItem.accentColor)
        let destinationURL: URL? = {
            guard let rawCandidate = apiItem.destinationURLString else { return nil }
            let raw = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            guard let url = ExternalURLPolicy.normalizedURL(from: raw) else { return nil }
            guard ExternalURLPolicy.isAllowed(url) else { return nil }
            return url
        }()

        let localizedTitle = RegionRuntime.semanticLocalized(resolvedTitle)
        let localizedSubtitle = RegionRuntime.semanticLocalized(resolvedSubtitle)
        let localizedSymbol = RegionRuntime.localizedAssetName(for: normalizedID, fallback: symbolName)

        return DiscoveryItem(
            id: normalizedID,
            title: localizedTitle,
            subtitle: localizedSubtitle,
            symbolName: localizedSymbol,
            accent: accentColor,
            imageURL: imageURL,
            destinationURL: destinationURL
        )
    }

    private static func resolvedAccentColor(from rawHex: String?) -> Color {
        guard let rawHex else { return Theme.brandPrimary }
        let cleaned = rawHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6 else { return Theme.brandPrimary }
        return Color(hex: cleaned)
    }
}

struct ConfettiOverlay: UIViewRepresentable {
    @Binding var isTriggered: Bool

    final class Coordinator {
        var emitterLayer: CAEmitterLayer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            isTriggered = false
            return
        }
        guard isTriggered else { return }
        guard context.coordinator.emitterLayer == nil else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        emitter.emitterCells = Self.makeCells()
        uiView.layer.addSublayer(emitter)
        context.coordinator.emitterLayer = emitter

        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        feedback.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + AppTheme.Layout.confettiStopDelay) {
            emitter.birthRate = 0
        }

        let coordinator = context.coordinator
        let triggerBinding = _isTriggered
        DispatchQueue.main.asyncAfter(deadline: .now() + AppTheme.Layout.confettiCleanupDelay) {
            emitter.removeFromSuperlayer()
            if coordinator.emitterLayer === emitter {
                coordinator.emitterLayer = nil
            }
            triggerBinding.wrappedValue = false
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.emitterLayer?.removeFromSuperlayer()
        coordinator.emitterLayer = nil
    }

    private static func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            .systemPurple,
            .systemPink,
            .systemBlue,
            .systemOrange,
            .systemGreen
        ]

        return colors.compactMap { color in
            guard let image = confettiBitImage(color: color)?.cgImage else { return nil }
            let cell = CAEmitterCell()
            cell.birthRate = AppTheme.Layout.confettiBirthRate / Float(colors.count)
            cell.lifetime = AppTheme.Layout.confettiLifetime
            cell.velocity = AppTheme.Layout.confettiVelocity
            cell.velocityRange = 50
            cell.scale = AppTheme.Layout.confettiScale
            cell.scaleRange = 0.06
            cell.emissionRange = AppTheme.Layout.confettiEmissionRange
            cell.spin = 3.5
            cell.spinRange = 2.0
            cell.contents = image
            return cell
        }
    }

    private static func confettiBitImage(color: UIColor) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 14))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: 10, height: 14)
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fill(rect)
        }
    }
}

struct StudentDiscountQRScannerSheet: View {
    let onClose: () -> Void
    let onOpenURL: (URL) -> Void

    @State private var cameraPermissionState: CameraPermissionState = .checking
    @State private var scannedCode: String?
    @State private var isScannerPaused = false
    @State private var statusMessage = "Align the QR code inside the frame."

    private var scannedURL: URL? {
        guard let scannedCode else { return nil }
        guard let normalized = ExternalURLPolicy.normalizedURL(from: scannedCode) else { return nil }
        guard ExternalURLPolicy.isAllowed(normalized) else { return nil }
        return normalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Label("Scan Student QR", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer(minLength: AppTheme.Spacing.sm)

                Button("Close") {
                    onClose()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .buttonStyle(AppFastButtonStyle())
            }

            switch cameraPermissionState {
            case .checking:
                ProgressView("Checking camera access...")
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            case .denied:
                deniedStateView
            case .authorized:
                scannerStateView
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .task {
            await resolveCameraPermission()
        }
    }

    private var scannerStateView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ZStack {
                QRCodeScannerPreview(
                    isPaused: $isScannerPaused,
                    onCodeDetected: { code in
                        guard scannedCode == nil else { return }
                        scannedCode = code
                        isScannerPaused = true

                        if scannedURL != nil {
                            Haptics.selectionIfAllowed()
                            statusMessage = "QR captured. Open the student offer."
                        } else {
                            statusMessage = "QR captured, but this code is not an approved link."
                        }
                    }
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                        style: .continuous
                    )
                )

                RoundedRectangle(
                    cornerRadius: AppTheme.Layout.discoveryTileCornerRadius,
                    style: .continuous
                )
                .stroke(AppTheme.Colors.actionPrimary.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                .padding(36)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 280)

            if let scannedCode {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(scannedCode)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Button("Scan Again") {
                            self.scannedCode = nil
                            isScannerPaused = false
                            statusMessage = "Align the QR code inside the frame."
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.bgSurface, in: Capsule())
                        .buttonStyle(AppFastButtonStyle())

                        if let scannedURL {
                            Button("Open Offer") {
                                onOpenURL(scannedURL)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.actionPrimary, in: Capsule())
                            .buttonStyle(AppFastButtonStyle())
                        } else {
                            Button("Copy Code") {
                                UIPasteboard.general.string = scannedCode
                                statusMessage = "Code copied."
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.actionPrimary, in: Capsule())
                            .buttonStyle(AppFastButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var deniedStateView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Camera access is required to scan student discount QR codes.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.actionPrimary, in: Capsule())
            .buttonStyle(AppFastButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.bgSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.Layout.discoveryPivotCornerRadius,
                style: .continuous
            )
        )
    }

    @MainActor
    private func resolveCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionState = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionState = granted ? .authorized : .denied
        case .denied, .restricted:
            cameraPermissionState = .denied
        @unknown default:
            cameraPermissionState = .denied
        }
    }
}

private enum CameraPermissionState {
    case checking
    case authorized
    case denied
}

private struct QRCodeScannerPreview: UIViewRepresentable {
    @Binding var isPaused: Bool
    let onCodeDetected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        context.coordinator.configureSessionIfNeeded(on: view)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updatePauseState(isPaused)
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: ScannerPreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerPreview
        private let session = AVCaptureSession()
        private var isConfigured = false
        fileprivate var previewLayer: AVCaptureVideoPreviewLayer?

        init(parent: QRCodeScannerPreview) {
            self.parent = parent
        }

        func configureSessionIfNeeded(on view: UIView) {
            guard !isConfigured else {
                previewLayer?.frame = view.bounds
                return
            }
            isConfigured = true

            session.beginConfiguration()
            session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer

            DispatchQueue.global(qos: .userInitiated).async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }

        func updatePauseState(_ isPaused: Bool) {
            if isPaused {
                if session.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.session.stopRunning()
                    }
                }
            } else {
                if !session.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.session.startRunning()
                    }
                }
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !parent.isPaused else { return }
            guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  first.type == .qr,
                  let value = first.stringValue
            else {
                return
            }
            parent.onCodeDetected(value)
        }

        func stopSession() {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}

private final class ScannerPreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }
}
