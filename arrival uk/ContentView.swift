import SwiftUI
import UIKit
import os
import AuthenticationServices
import SafariServices
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

private struct HomeCardMidYPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct HomeViewportCenterPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(StorageKey.homeCompletedSectionCollapsed.rawValue) private var isCompletedSectionCollapsed = true
    @AppStorage(StorageKey.homeSponsoredSlotEnabled.rawValue) private var isSponsoredSlotEnabled = true
    @AppStorage(StorageKey.homeHasLaunchedBefore.rawValue) private var hasLaunchedBefore = false
    @AppStorage(StorageKey.homeIsSettledMode.rawValue) private var isSettledMode = false
    @AppStorage(StorageKey.taskSyncLastOpenedTaskID.rawValue) private var restoredTaskID = ""
    @AppStorage(StorageKey.taskSyncLastOpenedCategoryID.rawValue) private var restoredCategoryID = ""
    @State private var completionStreak = StreakManager.shared.currentStreak
    @StateObject private var motionManager = MotionManager()
    @State private var store = ContentStore.shared
    @State private var adCoordinator = AdCoordinator()
    @State private var profileStore = StudentProfileStore.shared
    @State private var walletManager = WalletManager()
    @State private var taskEngine = TaskEngine()
    @State private var collaborationEngine = CollaborationSyncEngine.shared
    @State private var marketplaceCoordinator = MarketplaceFulfillmentCoordinator.shared
    @State private var lowPowerModeManager = LowPowerModeManager.shared
    @State private var taskSyncStore = TaskSyncStore.shared
    @State private var configService = ConfigService.shared
    @State private var activeWebURL: URL?
    @State private var isProfileSheetPresented = false
    @State private var activeModal: ActiveModal?
    @State private var selectedCategoryIndex: Int?
    @State private var enableDecorativeEffects = false
    @State private var isScrollActive = false
    @State private var scrollIdleResetTask: Task<Void, Never>?
    @State private var persistProgressTask: Task<Void, Never>?
    @State private var bootstrapWatchdogTask: Task<Void, Never>?
    @State private var homeClock = Date()
    @State private var minuteTickerTask: Task<Void, Never>?
    @State private var didBroadcastSwipeDismissForCurrentDrag = false
    @State private var toastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var hasTrackedSponsoredSlotImpression = false
    @State private var selectedTimelineFilter: HomeTimelineFilter = .all
    @State private var isInitialBootstrapInFlight = false
    @State private var hasCompletedInitialBootstrap = false
    @State private var hasLoadedBundleOnce = false
    @State private var isSettledConfettiTriggered = false
    @State private var homeViewportCenterY: CGFloat = 0
    @State private var cardMidYByCategoryID: [String: CGFloat] = [:]
    @State private var pendingWidgetRoute: ArrivalWidgetRoute.TaskTarget?
    @State private var pendingTaskGuideCategoryID: String?
    @State private var pendingTaskGuideTaskID: String?
    @State private var pendingHomeScrollAnchorID: String?
    @Namespace private var categoryHeroNamespace

    init() {
        LaunchMetrics.mark(event: "content_view_init")
    }

    enum HomeTimelineFilter: String, CaseIterable, Hashable {
        case all
        case beforeArrival
        case weekOne
        case weekTwo
        case anytime
        case completed

        var title: String {
            switch self {
            case .all:
                return HomeLocalization.filterAllTitle
            case .beforeArrival:
                return HomeLocalization.filterBeforeArrivalTitle
            case .weekOne:
                return HomeLocalization.filterWeekOneTitle
            case .weekTwo:
                return HomeLocalization.filterWeekTwoTitle
            case .anytime:
                return HomeLocalization.filterAnytimeTitle
            case .completed:
                return HomeLocalization.filterCompletedTitle
            }
        }
    }

    static func normalizedTimelineFilter(
        _ current: HomeTimelineFilter,
        availableFilters: [HomeTimelineFilter]
    ) -> HomeTimelineFilter {
        guard !availableFilters.isEmpty else {
            return .all
        }
        if availableFilters.contains(current) {
            return current
        }
        return availableFilters.contains(.all) ? .all : (availableFilters.first ?? .all)
    }

    static func timelineFilterSelection(
        for optionID: String,
        availableFilters: [HomeTimelineFilter]
    ) -> HomeTimelineFilter? {
        let canonicalID = canonicalTimelineFilterID(for: optionID)
        guard let candidate = HomeTimelineFilter(rawValue: canonicalID) else {
            return nil
        }
        return availableFilters.contains(candidate) ? candidate : nil
    }

    private static func canonicalTimelineFilterID(for optionID: String) -> String {
        let trimmed = optionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "all":
            return HomeTimelineFilter.all.rawValue
        case "beforearrival":
            return HomeTimelineFilter.beforeArrival.rawValue
        case "week1", "weekone":
            return HomeTimelineFilter.weekOne.rawValue
        case "week2", "weektwo", "week3", "weekthree", "month1", "monthone", "weeks24", "weeks2to4", "weeks2through4":
            return HomeTimelineFilter.weekTwo.rawValue
        case "anytime":
            return HomeTimelineFilter.anytime.rawValue
        case "completed", "done":
            return HomeTimelineFilter.completed.rawValue
        default:
            return trimmed
        }
    }

    private var prefersConservativeVisuals: Bool {
        PerformanceProfile.prefersConservativeVisuals || store.categories.count >= 18
    }

    private var prefersReducedMotion: Bool {
        reduceMotion || prefersConservativeVisuals
    }

    private var timelinePrimaryMetric: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let arrivalDay = calendar.startOfDay(for: profileStore.arrivalDate)
        let deltaDays = calendar.dateComponents([.day], from: today, to: arrivalDay).day ?? 0

        if deltaDays > 0 {
            return HomeLocalization.timelineUntilArrival(days: deltaDays)
        }

        if deltaDays == 0 {
            return HomeLocalization.timelineArrivalDay
        }

        let daysSinceArrival = abs(deltaDays)
        return HomeLocalization.timelineDayInUK(daysSinceArrival)
    }

    private var overallCompletionPercent: Int {
        let stats = ChecklistStats(categories: store.categories)
        guard stats.totalTasks > 0 else { return 0 }
        return Int((stats.overallProgress * 100).rounded(.down))
    }

    private var adaptiveHeaderMessage: String {
        HomeLocalization.adaptiveHeaderMessage(for: overallCompletionPercent)
    }

    private var copilotHeaderViewModel: HeaderViewModel {
        HeaderViewModel(
            userName: profileStore.preferredFirstName ?? profileStore.fullName,
            arrivalDate: profileStore.arrivalDate,
            tasksCompletedPercentage: overallCompletionPercent,
            currentDate: homeClock,
            isSettledMode: isSettledMode
        )
    }

    private var visibleCategoryIndices: [Int] {
        store.categories.indices
            .filter { index in
                let category = store.categories[index]
                guard category.isVisible else { return false }
                guard !category.tasks.isEmpty else { return false }
                return category.matchesAudience(
                    city: profileStore.city,
                    university: profileStore.selectedUniversity
                )
            }
            .sorted { lhs, rhs in
                let leftCategory = store.categories[lhs]
                let rightCategory = store.categories[rhs]

                if leftCategory.isCompleted != rightCategory.isCompleted {
                    return !leftCategory.isCompleted && rightCategory.isCompleted
                }

                if !leftCategory.isCompleted {
                    switch (leftCategory.deadlineDate, rightCategory.deadlineDate) {
                    case (.some(let leftDate), .some(let rightDate)):
                        if leftDate != rightDate {
                            return leftDate < rightDate
                        }
                    case (.some, .none):
                        return true
                    case (.none, .some):
                        return false
                    case (.none, .none):
                        break
                    }

                    if leftCategory.remainingTaskCount != rightCategory.remainingTaskCount {
                        return leftCategory.remainingTaskCount < rightCategory.remainingTaskCount
                    }

                    if leftCategory.visualPriority.ranking != rightCategory.visualPriority.ranking {
                        return leftCategory.visualPriority.ranking < rightCategory.visualPriority.ranking
                    }
                } else {
                    let leftRecent = leftCategory.mostRecentCompletionDate ?? .distantPast
                    let rightRecent = rightCategory.mostRecentCompletionDate ?? .distantPast
                    if leftRecent != rightRecent {
                        return leftRecent > rightRecent
                    }
                }

                let leftOrder = leftCategory.order ?? .max
                let rightOrder = rightCategory.order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return leftCategory.id < rightCategory.id
            }
    }

    private var audienceVisibleCategories: [ChecklistCategory] {
        visibleCategoryIndices.compactMap { index in
            guard store.categories.indices.contains(index) else { return nil }
            return store.categories[index]
        }
    }

    private enum HomeTimelineSection: String, CaseIterable {
        case beforeArrival
        case firstWeek
        case firstMonth
        case anytime
        case completed

        init(urgencyBand: CategoryUrgencyBand) {
            switch urgencyBand {
            case .immediate:
                self = .beforeArrival
            case .week1:
                self = .firstWeek
            case .week2:
                self = .firstMonth
            case .anytime:
                self = .anytime
            case .completed:
                self = .completed
            }
        }

        var title: String {
            switch self {
            case .beforeArrival:
                return HomeLocalization.sectionBeforeArrivalTitle
            case .firstWeek:
                return HomeLocalization.sectionWeekOneTitle
            case .firstMonth:
                return HomeLocalization.sectionMonthOneTitle
            case .anytime:
                return HomeLocalization.sectionAnytimeTitle
            case .completed:
                return HomeLocalization.sectionCompletedTitle
            }
        }

        var subtitle: String {
            switch self {
            case .beforeArrival:
                return HomeLocalization.sectionBeforeArrivalSubtitle
            case .firstWeek:
                return HomeLocalization.sectionWeekOneSubtitle
            case .firstMonth:
                return HomeLocalization.sectionMonthOneSubtitle
            case .anytime:
                return HomeLocalization.sectionAnytimeSubtitle
            case .completed:
                return HomeLocalization.sectionCompletedSubtitle
            }
        }
    }

    private struct HomeCategorySection: Identifiable {
        let timeline: HomeTimelineSection
        let indices: [Int]

        var id: String {
            timeline.rawValue
        }
    }

    private struct HomeCategoryCardMetrics {
        let completedCount: Int
        let totalCount: Int
        let isComplete: Bool
        let metaLine: String
    }

    private struct TodayTaskContext {
        let categoryIndex: Int
        let category: ChecklistCategory
        let task: ChecklistTask
    }

    private struct HandoffTaskPayload {
        let taskID: String
        let categoryID: String
        let taskTitle: String
    }

    private enum HomeScrollAnchor {
        static let topSection = "home-top-section"
        static let walletSection = "home-wallet-section"
    }

    private var activeHandoffTaskPayload: HandoffTaskPayload? {
        guard let categoryID = pendingTaskGuideCategoryID,
              let taskID = pendingTaskGuideTaskID,
              let category = store.categories.first(where: { $0.id == categoryID }),
              let task = category.tasks.first(where: { $0.id == taskID }) else {
            return nil
        }
        return HandoffTaskPayload(taskID: taskID, categoryID: categoryID, taskTitle: task.title)
    }

    private var visibleCategorySections: [HomeCategorySection] {
        var grouped: [HomeTimelineSection: [Int]] = [:]
        for index in visibleCategoryIndices {
            let section = HomeTimelineSection(urgencyBand: store.categories[index].urgencyBand)
            grouped[section, default: []].append(index)
        }

        return HomeTimelineSection.allCases.compactMap { section in
            guard let indices = grouped[section], !indices.isEmpty else {
                return nil
            }
            return HomeCategorySection(timeline: section, indices: indices)
        }
    }

    private func timelineFilter(for section: HomeTimelineSection) -> HomeTimelineFilter {
        switch section {
        case .beforeArrival:
            return .beforeArrival
        case .firstWeek:
            return .weekOne
        case .firstMonth:
            return .weekTwo
        case .anytime:
            return .anytime
        case .completed:
            return .completed
        }
    }

    private var availableTimelineFilters: [HomeTimelineFilter] {
        var filters: [HomeTimelineFilter] = [.all]
        let availableSections = Set(visibleCategorySections.map(\.timeline))

        for section in HomeTimelineSection.allCases where availableSections.contains(section) {
            let mapped = timelineFilter(for: section)
            if !filters.contains(mapped) {
                filters.append(mapped)
            }
        }

        return filters
    }

    private var timelineFilterOptions: [HomeTimelineFilterOption] {
        var seen = Set<String>()
        return availableTimelineFilters.compactMap {
            guard seen.insert($0.rawValue).inserted else { return nil }
            return HomeTimelineFilterOption(id: $0.rawValue, title: $0.title)
        }
    }

    private var filteredCategorySections: [HomeCategorySection] {
        guard selectedTimelineFilter != .all else {
            return visibleCategorySections
        }

        return visibleCategorySections.filter { section in
            timelineFilter(for: section.timeline) == selectedTimelineFilter
        }
    }

    private var visibleCardRankByCategoryID: [String: Int] {
        let orderedIndices = filteredCategorySections.flatMap(\.indices)
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(orderedIndices.count)

        for (rank, index) in orderedIndices.enumerated() where store.categories.indices.contains(index) {
            ranks[store.categories[index].id] = rank
        }

        return ranks
    }

    private var todayTaskContext: TodayTaskContext? {
        for index in visibleCategoryIndices where store.categories.indices.contains(index) {
            let category = store.categories[index]
            guard !category.isCompleted else { continue }
            guard category.urgencyBand == .immediate || category.urgencyBand == .week1 else { continue }
            guard let task = category.nextIncompleteTask else { continue }
            return TodayTaskContext(categoryIndex: index, category: category, task: task)
        }
        return nil
    }

    private var selectedCategoryBinding: Binding<ChecklistCategory>? {
        guard let index = selectedCategoryIndex else { return nil }
        guard store.categories.indices.contains(index) else { return nil }
        return $store.categories[index]
    }

    private var pendingTaskGuideRequestForSelectedCategory: String? {
        guard let selectedCategoryIndex else { return nil }
        guard store.categories.indices.contains(selectedCategoryIndex) else { return nil }
        let selectedCategoryID = store.categories[selectedCategoryIndex].id
        guard pendingTaskGuideCategoryID == selectedCategoryID else { return nil }
        return pendingTaskGuideTaskID
    }

    private var sectionGridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(minimum: 260), spacing: 10, alignment: .top),
                GridItem(.flexible(minimum: 260), spacing: 10, alignment: .top)
            ]
        }
        return [GridItem(.flexible(), spacing: Theme.spaceM, alignment: .top)]
    }

    private var selectedCategoryHeroID: String? {
        guard let index = selectedCategoryIndex else { return nil }
        return heroID(for: index)
    }

    private var isCategoryOverlayPresented: Bool {
        selectedCategoryBinding != nil
    }

    private var sponsoredSlotURL: URL? {
        ExternalURLPolicy.normalizedURL(from: "https://www.giffgaff.com")
    }

    private var shouldShowSponsoredSlot: Bool {
        isSponsoredSlotEnabled && AdRuntime.isAdsEnabledForCurrentBuild && sponsoredSlotURL != nil
    }

    private var canTrackHomeAnalyticsRemotely: Bool {
        guard profileStore.authProvider != .none else { return false }

        let hasStableIdentity =
            profileStore.googleUserID?.isEmpty == false ||
            profileStore.appleUserID?.isEmpty == false ||
            profileStore.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        return hasStableIdentity
    }

    private var completedSectionItemCount: Int {
        filteredCategorySections
            .first(where: { $0.timeline == .completed })?
            .indices
            .count ?? 0
    }

    private var hasAnyCompletedTask: Bool {
        store.categories.contains { category in
            category.tasks.contains(where: \.isComplete)
        }
    }

    private var suggestedStartCategoryID: String? {
        guard !hasAnyCompletedTask else { return nil }
        let preferredIndex = visibleCategoryIndices.first { index in
            store.categories.indices.contains(index) && store.categories[index].urgencyBand == .immediate
        } ?? visibleCategoryIndices.first

        guard let preferredIndex, store.categories.indices.contains(preferredIndex) else {
            return nil
        }

        return store.categories[preferredIndex].id
    }

    private var homeStackSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 13 : 11
    }

    private var sectionSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Theme.spaceL : Theme.spaceM
    }

    private var gridSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 13 : 10
    }

    private var contentHorizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 16
    }

    private var contentBottomPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 142 : 106
    }

    private var staggeredContentBaseIndex: Int {
        let filterOffset = availableTimelineFilters.isEmpty ? 3 : 4
        let todayOffset = todayTaskContext == nil ? 0 : 1
        return filterOffset + todayOffset + (shouldShowSponsoredSlot ? 1 : 0)
    }

    private var scrollCueBackgroundColor: Color {
        colorScheme == .dark ? Theme.navy900 : Theme.backgroundPrimary
    }

    private func taskProgressCounts(for section: HomeCategorySection) -> (completed: Int, total: Int) {
        var completed = 0
        var total = 0

        for index in section.indices where store.categories.indices.contains(index) {
            let stats = CategoryStats(tasks: store.categories[index].tasks)
            completed += stats.completedCount
            total += stats.totalCount
        }

        return (completed, total)
    }

    private func cardMetrics(for index: Int) -> HomeCategoryCardMetrics {
        guard store.categories.indices.contains(index) else {
            return HomeCategoryCardMetrics(
                completedCount: 0,
                totalCount: 0,
                isComplete: false,
                metaLine: HomeLocalization.taskProgressLine(completedCount: 0, totalCount: 0)
            )
        }

        let stats = CategoryStats(tasks: store.categories[index].tasks)
        let isComplete = stats.totalCount > 0 && stats.completedCount == stats.totalCount
        let metaLine = isComplete
            ? HomeLocalization.categoryCompleteLine
            : HomeLocalization.taskProgressLine(completedCount: stats.completedCount, totalCount: stats.totalCount)

        return HomeCategoryCardMetrics(
            completedCount: stats.completedCount,
            totalCount: stats.totalCount,
            isComplete: isComplete,
            metaLine: metaLine
        )
    }

    private func tiltDegrees(for categoryID: String) -> Double {
        guard let rank = visibleCardRankByCategoryID[categoryID], rank > 0 else { return 0 }
        return min(Double(rank) * 0.5, 2.0)
    }

    private func shouldHighlightSuggestedStart(for index: Int) -> Bool {
        guard selectedTimelineFilter == .all else { return false }
        guard let suggestedStartCategoryID else { return false }
        guard store.categories.indices.contains(index) else { return false }
        return store.categories[index].id == suggestedStartCategoryID
    }

    private var scrollCueTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Theme.secondaryText
    }

    private var displayedCategoryCount: Int {
        filteredCategorySections.reduce(0) { partial, section in
            partial + section.indices.count
        }
    }

    private var showsScrollContinuationCue: Bool {
        hasCompletedInitialBootstrap &&
        displayedCategoryCount > 3 &&
        !isScrollActive &&
        !isCategoryOverlayPresented &&
        activeModal == nil
    }

    private var homeScrollView: some View {
        GeometryReader { proxy in
            let safeAreaTopInset = proxy.safeAreaInsets.top
            let safeAreaBottomInset = proxy.safeAreaInsets.bottom

            ScrollView {
                LazyVStack(spacing: homeStackSpacing) {
                    CopilotHeaderView(
                        viewModel: copilotHeaderViewModel,
                        onSearchTap: {
                            presentSheet(.search)
                        },
                        onProfileTap: {
                            presentSheet(.profileSetup)
                        },
                        isSettledMode: isSettledMode,
                        onUtilityTap: {
                            if isSettledMode {
                                presentSheet(.scanQR)
                            } else {
                                presentSheet(.addTask(defaultCategoryID: nil))
                            }
                        },
                        topSafeAreaInset: safeAreaTopInset,
                        collaborationPresenceText: collaborationEngine.presenceBadgeText
                    )
                    .id(HomeScrollAnchor.topSection)
                    .staggeredEntry(index: 0, isActive: true, prefersReducedMotion: prefersReducedMotion)

                    if let todayTaskContext {
                        TodayCard(
                            task: todayTaskContext.task,
                            category: todayTaskContext.category,
                            onTap: {
                                openTodayTask(todayTaskContext)
                            }
                        )
                        .staggeredEntry(index: 1, isActive: true, prefersReducedMotion: prefersReducedMotion)
                    }

                    if visibleCategoryIndices.isEmpty {
                        HomeEmptyStateView()
                            .padding(.top, Theme.spaceL)
                    } else {
                        VStack(alignment: .leading, spacing: Theme.spaceL) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your checklist")
                                    .font(ArrivalTypography.figtree(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.primaryText)

                                Text(timelinePrimaryMetric)
                                    .font(ArrivalTypography.figtree(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                            }

                            LazyVGrid(columns: sectionGridColumns, alignment: .leading, spacing: gridSpacing) {
                                ForEach(Array(visibleCategoryIndices.enumerated()), id: \.element) { position, index in
                                    if store.categories.indices.contains(index) {
                                        let metrics = cardMetrics(for: index)
                                        CategoryCard(
                                            category: $store.categories[index],
                                            completedTaskCount: metrics.completedCount,
                                            totalTaskCount: metrics.totalCount,
                                            isCategoryComplete: metrics.isComplete,
                                            isPulsing: todayTaskContext?.category.id == store.categories[index].id,
                                            heroNamespace: categoryHeroNamespace,
                                            heroID: heroID(for: index),
                                            isHeroSourceHidden: selectedCategoryIndex == index,
                                            suppressShadow: prefersConservativeVisuals && isScrollActive,
                                            isSuggestedStart: shouldHighlightSuggestedStart(for: index),
                                            cardIndex: index,
                                            tiltDegrees: tiltDegrees(for: store.categories[index].id),
                                            motionTilt: prefersReducedMotion ? .zero : motionManager.tilt,
                                            onOpenCategory: {
                                                openCategory(at: index)
                                            }
                                        )
                                        .background(
                                            GeometryReader { proxy in
                                                Color.clear.preference(
                                                    key: HomeCardMidYPreferenceKey.self,
                                                    value: [store.categories[index].id: proxy.frame(in: .global).midY]
                                                )
                                            }
                                        )
                                        .staggeredEntry(
                                            index: position + 2,
                                            isActive: true,
                                            prefersReducedMotion: prefersReducedMotion
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, Theme.spaceXS)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 16)
                .padding(
                    .bottom,
                    contentBottomPadding + max(safeAreaBottomInset, AppTheme.Spacing.md)
                )
            }
        }
        .refreshable {
            Haptics.selectionIfAllowed()
            await refreshHomeContext()
        }
        .zIndex(LayerZIndex.base)
        .opacity(hasCompletedInitialBootstrap ? 1 : 0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in markScrollActive(with: value.translation) }
                .onEnded { _ in markScrollEnded() }
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: HomeViewportCenterPreferenceKey.self,
                    value: proxy.frame(in: .global).midY
                )
            }
        )
        .onPreferenceChange(HomeViewportCenterPreferenceKey.self) { homeViewportCenterY = $0 }
        .onPreferenceChange(HomeCardMidYPreferenceKey.self) { cardMidYByCategoryID = $0 }
        .animation(Motion.heroBackground(prefersReducedMotion: prefersReducedMotion), value: isCategoryOverlayPresented)
        .opacity(isCategoryOverlayPresented ? 0.34 : 1)
        .animation(.easeOut(duration: prefersReducedMotion ? 0.20 : 0.35), value: isCategoryOverlayPresented)
        .allowsHitTesting(
            hasCompletedInitialBootstrap &&
            !isCategoryOverlayPresented &&
            activeModal == nil
        )
    }

    @ViewBuilder
    private var startupPlaceholderOverlay: some View {
        if !hasCompletedInitialBootstrap {
            StartupPlaceholderView(primaryMetric: timelinePrimaryMetric)
                .transition(.opacity)
                .zIndex(LayerZIndex.stickyHeader)
        }
    }

    @ViewBuilder
    private var scrollContinuationCueOverlay: some View {
        if showsScrollContinuationCue {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LinearGradient(
                    colors: [Color.clear, scrollCueBackgroundColor.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 72)
                .overlay(alignment: .bottom) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(scrollCueTextColor)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .zIndex(LayerZIndex.base + 1)
        }
    }

    @ViewBuilder
    private var categoryOverlayView: some View {
        if let selectedCategory = selectedCategoryBinding {
            CategoryDetailOverlay(
                category: selectedCategory,
                allCategories: store.categories,
                namespace: categoryHeroNamespace,
                heroID: selectedCategoryHeroID ?? "",
                prefersReducedMotion: prefersReducedMotion,
                onClose: closeCategoryDetail,
                onToggleTask: {
                    registerAdEvent(.taskToggled)
                    Task {
                        await NotificationManager.shared.refreshTaskReminders(
                            categories: store.categories
                        )
                    }
                },
                onOpenTaskGuide: {
                    registerAdEvent(.taskDetailOpened)
                },
                requestedTaskID: pendingTaskGuideRequestForSelectedCategory,
                onTaskGuideRequestConsumed: {
                    clearPendingTaskGuideRequest()
                }
            )
            .opacity(activeModal == nil ? 1 : 0)
            .allowsHitTesting(activeModal == nil)
            .transition(.opacity)
            .zIndex(LayerZIndex.categoryOverlay)
        }
    }

    @ViewBuilder
    private var activeModalOverlayView: some View {
        if let activeModal {
            BottomModalOverlay(
                maxHeightRatio: modalHeightRatio(for: activeModal),
                minHeightRatio: modalMinHeightRatio(for: activeModal),
                prefersReducedMotion: prefersReducedMotion,
                onDismiss: dismissActiveModal
            ) {
                modalView(for: activeModal)
            }
            .zIndex(LayerZIndex.modal)
        }
    }

    @ViewBuilder
    private var toastOverlayView: some View {
        if let toastMessage {
            ToastBanner(message: toastMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, Theme.spaceM)
                .padding(.top, Theme.spaceM)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(LayerZIndex.modal + 1)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var confettiOverlayView: some View {
        if !lowPowerModeManager.isLowPowerModeEnabled {
            ConfettiOverlay(isTriggered: $isSettledConfettiTriggered)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(LayerZIndex.modal + 2)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                let baseView = AnyView(baseHomeContentView)
                configuredHomeContentView(baseView, scrollProxy: scrollProxy)
            }
        }
    }

    private var baseHomeContentView: some View {
        ZStack {
            homeScrollView

            scrollContinuationCueOverlay

            startupPlaceholderOverlay

            categoryOverlayView

            activeModalOverlayView

            toastOverlayView

            confettiOverlayView
        }
        .background(
            Theme.background(
                for: colorScheme,
                conservative: prefersConservativeVisuals
            )
            .ignoresSafeArea()
        )
        .environment(taskEngine)
        .environment(walletManager)
        .environment(configService)
        .buttonStyle(AppFastButtonStyle())
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(
            get: { activeWebURL != nil },
            set: { isPresented in
                if !isPresented {
                    activeWebURL = nil
                }
            }
        )) {
            if let url = activeWebURL {
                InAppBrowserSheet(url: url)
            }
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            ProfileSetupSheet(
                store: profileStore,
                contentStore: store,
                onOpenHelp: {
                    isProfileSheetPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: AppTiming.profileHelpSheetPresentationDelay)
                        presentSheet(.help)
                    }
                },
                onClose: { isProfileSheetPresented = false }
            )
        }
        .environment(\.openURL, OpenURLAction { url in
            handleOpenURL(url)
        })
    }

    private func configuredHomeContentView(
        _ baseView: AnyView,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let continuityView = AnyView(
            baseView
                .userActivity(
                    ArrivalContinuity.taskGuideActivityType,
                    isActive: activeHandoffTaskPayload != nil
                ) { activity in
                    guard let payload = activeHandoffTaskPayload else { return }
                    activity.title = "Continue: \(payload.taskTitle)"
                    activity.isEligibleForHandoff = true
                    activity.isEligibleForSearch = true
                    activity.isEligibleForPrediction = true
                    activity.persistentIdentifier = "task-\(payload.taskID)"
                    activity.userInfo = [
                        ArrivalContinuity.taskIDKey: payload.taskID,
                        ArrivalContinuity.categoryIDKey: payload.categoryID,
                        ArrivalContinuity.taskTitleKey: payload.taskTitle
                    ]
                    activity.webpageURL = URL(string: "https://arrivaluk.app/handoff/task/\(payload.taskID)")
                }
                .onOpenURL { url in
                    processIncomingURL(url)
                }
                .onContinueUserActivity(ArrivalContinuity.taskGuideActivityType) { activity in
                    handleContinuedTaskGuideActivity(activity)
                }
                .onContinueUserActivity(ArrivalContinuity.openDocumentActivityType) { activity in
                    handleContinuedOpenDocumentActivity(activity)
                }
                .onReceive(NotificationCenter.default.publisher(for: .didTapRemoteNotification)) { notification in
                    handleNotificationTap(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .didReceiveSilentCollaborationSync)) { _ in
                    applyCollaborativeCompletionOverlayIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .didCompleteMarketplaceTask)) { notification in
                    handleMarketplaceCompletion(notification)
                }
        )

        return continuityView
            .onChange(of: scenePhase) { _, newValue in
                walletManager.handleScenePhaseChange(newValue)
                taskSyncStore.handleScenePhaseChange(newValue)
                collaborationEngine.markLocalPresence(isActive: newValue == .active)
                if newValue == .active {
                    Task {
                        await configService.refreshIfNeeded(reason: "scene_active", force: false)
                    }
                    AdRuntime.updateConsentConfiguration()
                    registerAdEvent(.appBecameActive)
                    store.updateTaskViewDates()
                    completionStreak = StreakManager.shared.currentStreak
                    if !prefersReducedMotion {
                        motionManager.start()
                    }
                    ensureRenderableState(reason: "scene_active")
                    consumePendingIntentRouteIfNeeded()
                } else if newValue == .inactive || newValue == .background {
                    motionManager.stop()
                    store.persistProgress()
                    CrashSessionGuard.updateRecoveryCheckpoint(
                        settledMode: isSettledMode,
                        survivalCount: taskEngine.survivalQueue.count,
                        maintenanceCount: taskEngine.maintenanceTasks.count
                    )
                    LaunchMetrics.mark(event: "content_progress_flushed_scene_\(scenePhaseLabel(newValue))")
                }
            }
            .onChange(of: shouldShowSponsoredSlot) { _, isVisible in
                if !isVisible {
                    hasTrackedSponsoredSlotImpression = false
                }
            }
            .onChange(of: sponsoredSlotURL?.absoluteString) { _, _ in
                hasTrackedSponsoredSlotImpression = false
            }
            .onChange(of: isSettledMode) { _, _ in
                refreshTaskEngine()
            }
            .onChange(of: configService.current) { _, _ in
                refreshTaskEngine()
                walletManager.apply(config: configService.effectivePhase4WalletConfig)
            }
            .onChange(of: availableTimelineFilters) { _, nextFilters in
                let normalized = Self.normalizedTimelineFilter(
                    selectedTimelineFilter,
                    availableFilters: nextFilters
                )
                if normalized != selectedTimelineFilter {
                    selectedTimelineFilter = normalized
                }
            }
            .onChange(of: store.categories) { _, _ in
                if !hasCompletedInitialBootstrap, !store.categories.isEmpty {
                    hasCompletedInitialBootstrap = true
                    LaunchMetrics.mark(event: "content_unblocked_on_category_change")
                }
                if hasCompletedInitialBootstrap {
                    bootstrapWatchdogTask?.cancel()
                }
                completionStreak = StreakManager.shared.currentStreak
                ArrivalWidgetSupport.syncSnapshot(categories: store.categories)
                consumePendingWidgetRouteIfPossible()
                scheduleProgressPersistence()
                refreshTaskEngine()
                applyTaskSyncCompletionOverlayIfNeeded()
                applyCollaborativeCompletionOverlayIfNeeded()
                restoreColdStartTaskSnapshotIfPossible()
                Task {
                    await NotificationManager.shared.refreshTaskReminders(
                        categories: store.categories
                    )
                }
            }
            .onChange(of: profileStore.city) { _, _ in
                refreshTaskEngine()
            }
            .onChange(of: profileStore.selectedUniversity) { _, _ in
                refreshTaskEngine()
            }
            .onChange(of: pendingHomeScrollAnchorID) { _, anchorID in
                guard let anchorID else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    scrollProxy.scrollTo(anchorID, anchor: .top)
                }
                pendingHomeScrollAnchorID = nil
            }
            .onDisappear {
                scrollIdleResetTask?.cancel()
                persistProgressTask?.cancel()
                bootstrapWatchdogTask?.cancel()
                minuteTickerTask?.cancel()
                minuteTickerTask = nil
                toastDismissTask?.cancel()
                toastDismissTask = nil
                motionManager.stop()
                collaborationEngine.markLocalPresence(isActive: false)
            }
            .task {
                await bootstrapInitialViewStateIfNeeded()
                configService.configureIfNeeded()
                await configService.refreshIfNeeded(reason: "content_task_bootstrap", force: false)
                lowPowerModeManager.configureIfNeeded()
                taskSyncStore.configureIfNeeded()
                collaborationEngine.configureIfNeeded()
                collaborationEngine.markLocalPresence(isActive: scenePhase == .active)
                walletManager.apply(config: configService.effectivePhase4WalletConfig)
                walletManager.bootstrapIfNeeded()
                walletManager.handleScenePhaseChange(scenePhase)
                startHomeClockTickerIfNeeded()
                await refreshHomeContext()
                applyTaskSyncCompletionOverlayIfNeeded()
                refreshTaskEngine()
                restoreColdStartTaskSnapshotIfPossible()
                consumePendingIntentRouteIfNeeded()
                if !prefersReducedMotion {
                    motionManager.start()
                }
                markHomeLaunchAnimationConsumedIfNeeded()
            }
            .phase12VisionOrnament(
                onHomeTap: {
                    pendingHomeScrollAnchorID = HomeScrollAnchor.topSection
                },
                onWalletTap: {
                    openWalletFromWidgetRoute(shouldUnlock: false)
                },
                onQuickTaskTap: {
                    _ = openQuickTaskFromRoute()
                }
            )
    }

    @MainActor
    private func bootstrapInitialViewStateIfNeeded() async {
        guard !isInitialBootstrapInFlight, !hasLoadedBundleOnce else { return }

        isInitialBootstrapInFlight = true
        armBootstrapWatchdogIfNeeded()
        defer { isInitialBootstrapInFlight = false }

        LaunchMetrics.mark(event: "content_view_task_begin")
        CrashReporter.log("content bootstrap started", level: .info)
        let recoveredSettledMode = CrashSessionGuard.restoreSettledModeIfNeeded(currentValue: isSettledMode)
        if recoveredSettledMode != isSettledMode {
            isSettledMode = recoveredSettledMode
        }

        // Prime immediately with bundled sample content so first paint never appears blank.
        store.primeWithSampleDataIfNeeded()
        hasCompletedInitialBootstrap = true
        LaunchMetrics.mark(event: "content_unblocked_with_prime_data")

        // Yield once so the placeholder can paint before background loading starts.
        await Task.yield()

        if AdRuntime.isAdsEnabledForCurrentBuild {
            AdRuntime.bootstrapIfNeeded()
            adCoordinator.startSessionIfNeeded()
        }
        profileStore.bootstrapIfNeeded()
        await loadContentIfNeeded()
        await NotificationManager.shared.refreshTaskReminders(
            categories: store.categories
        )
        ArrivalWidgetSupport.syncSnapshot(categories: store.categories)

        LaunchMetrics.mark(event: "content_loaded_in_view")
        LaunchMetrics.markStartupBudget(
            milestone: "content_loaded_in_view",
            warningThresholdSeconds: 2.5
        )
        CrashReporter.log("content bootstrap completed categories=\(store.categories.count)", level: .info)
        await enableEffectsAfterFirstFrame()
        ensureRenderableState(reason: "bootstrap_complete")
        presentAdDisclosureIfNeeded()
        bootstrapWatchdogTask?.cancel()
    }

    @MainActor
    private func loadContentIfNeeded() async {
        guard !hasLoadedBundleOnce else { return }
        hasLoadedBundleOnce = true
        await store.loadFromBundle()
        ensureRenderableState(reason: "bundle_load_complete")
    }

    @MainActor
    private func scheduleProgressPersistence() {
        persistProgressTask?.cancel()
        persistProgressTask = Task(priority: .utility) {
            try? await Task.sleep(for: AppTiming.progressPersistenceCoalescingDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                store.persistProgress()
            }
        }
    }

    @MainActor
    private func enableEffectsAfterFirstFrame() async {
        guard !enableDecorativeEffects else { return }

        guard !prefersConservativeVisuals else {
            LaunchMetrics.mark(event: "decorative_effects_skipped_conservative_mode")
            return
        }

        try? await Task.sleep(for: AppTiming.decorativeEffectsEnableDelay)
        enableDecorativeEffects = true
        LaunchMetrics.mark(event: "decorative_effects_enabled")
    }

    @MainActor
    private func registerAdEvent(_ event: AdEvent) {
        guard AdRuntime.isAdsEnabledForCurrentBuild else { return }
        if let opportunity = adCoordinator.register(event: event) {
            AdRuntime.requestAd(for: opportunity)
        }
    }

    @MainActor
    private func markScrollActive(with translation: CGSize) {
        scrollIdleResetTask?.cancel()

        if abs(translation.height) > abs(translation.width), !didBroadcastSwipeDismissForCurrentDrag {
            didBroadcastSwipeDismissForCurrentDrag = true
        }

        if isScrollActive { return }
        withAnimation(.linear(duration: 0.08)) {
            isScrollActive = true
        }
    }

    @MainActor
    private func markScrollEnded() {
        scrollIdleResetTask?.cancel()
        let shouldEmitHaptic = didBroadcastSwipeDismissForCurrentDrag
        didBroadcastSwipeDismissForCurrentDrag = false
        scrollIdleResetTask = Task { @MainActor in
            try? await Task.sleep(for: AppTiming.scrollIdleResetDelay)
            guard !Task.isCancelled else { return }
            if shouldEmitHaptic {
                Haptics.selectionIfAllowed()
            }
            withAnimation(.easeOut(duration: 0.20)) {
                isScrollActive = false
            }
        }
    }

    @MainActor
    private func selectTimelineFilter(_ nextFilter: HomeTimelineFilter) {
        guard selectedTimelineFilter != nextFilter else { return }

        Haptics.selectionIfAllowed()
        withAnimation(.easeInOut(duration: prefersReducedMotion ? 0.12 : 0.20)) {
            selectedTimelineFilter = nextFilter
        }

        trackHomeAnalytics(
            event: "home_timeline_filter_changed",
            properties: [
                "filter": nextFilter.rawValue,
                "isRTL": HomeLocalization.isRightToLeft
            ]
        )
        LaunchMetrics.mark(event: "home_filter_changed_\(nextFilter.rawValue)")
    }

    @MainActor
    private func toggleCompletedSection() {
        let nextCollapsedState = !isCompletedSectionCollapsed

        trackHomeAnalytics(
            event: "home_completed_section_toggled",
            properties: [
                "collapsed": nextCollapsedState,
                "itemCount": completedSectionItemCount,
                "isRTL": HomeLocalization.isRightToLeft
            ]
        )
        LaunchMetrics.mark(
            event: nextCollapsedState
                ? "home_completed_section_collapsed"
                : "home_completed_section_expanded"
        )

        Haptics.selectionIfAllowed()
        withAnimation(.easeInOut(duration: prefersReducedMotion ? 0.12 : 0.22)) {
            isCompletedSectionCollapsed.toggle()
        }
    }

    @MainActor
    private func trackSponsoredSlotImpressionIfNeeded() {
        guard !hasTrackedSponsoredSlotImpression else { return }
        hasTrackedSponsoredSlotImpression = true
        registerAdEvent(.sponsoredSlotImpression)
        trackHomeAnalytics(
            event: "home_sponsored_slot_impression",
            properties: ["placement": "home_header"]
        )
        LaunchMetrics.mark(event: "home_sponsored_slot_impression")
    }

    private func trackHomeAnalytics(event: String, properties: [String: Any]) {
        guard canTrackHomeAnalyticsRemotely else {
            return
        }

        Task(priority: .utility) { @MainActor in
            #if canImport(FirebaseCore)
            guard FirebaseApp.app() != nil else {
                return
            }
            #endif
            guard let authManager = AuthenticationManager.shared else {
                return
            }
            await authManager.trackHomeInteraction(
                event: event,
                properties: properties
            )
        }
    }

    @MainActor
    private func presentSheet(_ sheet: ActiveSheet) {
        switch sheet {
        case .web(let url):
            activeWebURL = url
        case .search:
            activeModal = .search
        case .addTask(let defaultCategoryID):
            activeModal = .addTask(defaultCategoryID: defaultCategoryID)
        case .scanQR:
            activeModal = .scanQR
        case .adPrivacy:
            activeModal = .adPrivacy
        case .help:
            activeModal = .help
        case .taskDetail(let task):
            if !openTaskGuide(taskID: task.id) {
                withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                    activeModal = .taskDetail(task)
                }
            }
        case .profileSetup:
            isProfileSheetPresented = true
        }
    }

    @MainActor
    private func dismissActiveModal() {
        withAnimation(Motion.modalDismiss(prefersReducedMotion: prefersReducedMotion)) {
            activeModal = nil
        }
    }

    @MainActor
    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastDismissTask = nil

        withAnimation(.easeOut(duration: 0.20)) {
            toastMessage = message
        }

        toastDismissTask = Task(priority: .utility) {
            try? await Task.sleep(for: AppTiming.toastAutoDismissDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.20)) {
                    toastMessage = nil
                }
            }
        }
    }

    @MainActor
    private func markTaskCompleteFromDetail(taskID: String) {
        let previousSurvivalCount = taskEngine.survivalQueue.count

        for categoryIndex in store.categories.indices {
            guard let taskIndex = store.categories[categoryIndex].tasks.firstIndex(where: { $0.id == taskID }) else {
                continue
            }

            if !store.categories[categoryIndex].tasks[taskIndex].isComplete {
                let completedAt = Date()
                let completedTask = store.categories[categoryIndex].tasks[taskIndex]
                let syncPhase = phaseForTaskSync(taskID: completedTask.id)

                store.categories[categoryIndex].tasks[taskIndex].isComplete = true
                store.categories[categoryIndex].tasks[taskIndex].completedAt = completedAt
                taskSyncStore.recordCompletion(
                    taskID: completedTask.id,
                    title: completedTask.title,
                    categoryID: store.categories[categoryIndex].id,
                    phase: syncPhase,
                    completedAt: completedAt
                )
                collaborationEngine.registerLocalCompletion(
                    taskID: completedTask.id,
                    title: completedTask.title,
                    categoryID: store.categories[categoryIndex].id,
                    isTier1Urgent: syncPhase == 1,
                    completedAt: completedAt
                )
                StreakManager.shared.recordTaskCompletion()
                completionStreak = StreakManager.shared.currentStreak
                registerAdEvent(.taskToggled)
                store.persistProgress()
                Task {
                    await NotificationManager.shared.refreshTaskReminders(
                        categories: store.categories
                    )
                }
                showToast("Task marked complete")
                refreshTaskEngine()
                maybeEnterSettledMode(previousSurvivalCount: previousSurvivalCount)
            }
            return
        }
    }

    @MainActor
    private func completePriorityTask(_ task: AppTask) {
        markTaskCompleteFromDetail(taskID: task.taskID)
    }

    @MainActor
    private func refreshTaskEngine() {
        taskEngine.apply(config: configService.current.phase3)
        taskEngine.apply(regionConfiguration: configService.activeRegionConfiguration)
        taskEngine.setSettledMode(isSettledMode)
        taskEngine.refresh(from: audienceVisibleCategories)
        taskSyncStore.mirrorQueues(
            survivalQueue: taskEngine.survivalQueue,
            maintenanceTasks: taskEngine.maintenanceTasks
        )
        CrashSessionGuard.updateRecoveryCheckpoint(
            settledMode: isSettledMode,
            survivalCount: taskEngine.survivalQueue.count,
            maintenanceCount: taskEngine.maintenanceTasks.count
        )
    }

    @MainActor
    private func phaseForTaskSync(taskID: String) -> Int {
        if taskEngine.survivalQueue.contains(where: { $0.taskID == taskID }) {
            return 1
        }
        if taskEngine.maintenanceTasks.contains(where: { $0.taskID == taskID }) {
            return 2
        }
        return 2
    }

    @MainActor
    private func applyTaskSyncCompletionOverlayIfNeeded() {
        let completionMap = taskSyncStore.localCompletionMap()
        guard !completionMap.isEmpty else { return }

        var didMutate = false
        for categoryIndex in store.categories.indices {
            for taskIndex in store.categories[categoryIndex].tasks.indices {
                let taskID = store.categories[categoryIndex].tasks[taskIndex].id
                guard let syncedCompletionDate = completionMap[taskID] else { continue }

                let localCompletionDate = store.categories[categoryIndex].tasks[taskIndex].completedAt ?? .distantPast
                let shouldApply = !store.categories[categoryIndex].tasks[taskIndex].isComplete ||
                    syncedCompletionDate > localCompletionDate
                guard shouldApply else { continue }

                store.categories[categoryIndex].tasks[taskIndex].isComplete = true
                store.categories[categoryIndex].tasks[taskIndex].completedAt = syncedCompletionDate
                didMutate = true
            }
        }

        if didMutate {
            store.persistProgress()
            refreshTaskEngine()
        }
    }

    @MainActor
    private func applyCollaborativeCompletionOverlayIfNeeded() {
        let completionMap = collaborationEngine.consumeCompletionOverlay()
        guard !completionMap.isEmpty else { return }

        var didMutate = false
        for categoryIndex in store.categories.indices {
            for taskIndex in store.categories[categoryIndex].tasks.indices {
                let taskID = store.categories[categoryIndex].tasks[taskIndex].id
                guard let completedAt = completionMap[taskID] else { continue }

                let localCompletedAt = store.categories[categoryIndex].tasks[taskIndex].completedAt ?? .distantPast
                let shouldApply = !store.categories[categoryIndex].tasks[taskIndex].isComplete ||
                    completedAt > localCompletedAt
                guard shouldApply else { continue }

                store.categories[categoryIndex].tasks[taskIndex].isComplete = true
                store.categories[categoryIndex].tasks[taskIndex].completedAt = completedAt
                didMutate = true
            }
        }

        if didMutate {
            store.persistProgress()
            refreshTaskEngine()
            showToast("Shared journey updated.")
        }
    }

    @MainActor
    private func restoreColdStartTaskSnapshotIfPossible() {
        guard !restoredTaskID.isEmpty else { return }
        guard pendingTaskGuideTaskID != restoredTaskID else { return }
        guard selectedCategoryIndex == nil else { return }

        let preferredCategoryID = restoredCategoryID.isEmpty ? nil : restoredCategoryID
        if openTaskGuide(taskID: restoredTaskID, preferredCategoryID: preferredCategoryID) {
            LaunchMetrics.mark(event: "cold_start_task_restored")
        }
    }

    @MainActor
    private func persistColdStartTaskSnapshot(taskID: String, categoryID: String) {
        restoredTaskID = taskID
        restoredCategoryID = categoryID
    }

    @MainActor
    private func clearColdStartTaskSnapshot() {
        restoredTaskID = ""
        restoredCategoryID = ""
    }

    @MainActor
    private func maybeEnterSettledMode(previousSurvivalCount: Int) {
        guard previousSurvivalCount > 0 else { return }
        guard !isSettledMode else { return }
        guard taskEngine.survivalQueue.isEmpty else { return }

        withAnimation(
            lowPowerModeManager.isLowPowerModeEnabled
                ? .easeOut(duration: 0.20)
                : .spring(response: 0.55, dampingFraction: 0.84)
        ) {
            isSettledMode = true
            taskEngine.setSettledMode(true)
        }
        isSettledConfettiTriggered = !lowPowerModeManager.isLowPowerModeEnabled
        if !lowPowerModeManager.isLowPowerModeEnabled {
            SpatialAudioCueEngine.shared.playSettledMilestoneCue()
        }
        showToast("Settled mode unlocked. Welcome to City Guide.")
    }

    @MainActor
    private func completeNextTask(inCategoryID categoryID: String) -> Bool {
        guard let categoryIndex = store.categories.firstIndex(where: { $0.id == categoryID }) else {
            playSelectionEchoHaptic()
            return false
        }

        let nextTaskIndex = store.categories[categoryIndex].tasks.indices
            .sorted { lhs, rhs in
                let leftOrder = store.categories[categoryIndex].tasks[lhs].order ?? .max
                let rightOrder = store.categories[categoryIndex].tasks[rhs].order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return store.categories[categoryIndex].tasks[lhs].id < store.categories[categoryIndex].tasks[rhs].id
            }
            .first { !store.categories[categoryIndex].tasks[$0].isComplete }

        guard let taskIndex = nextTaskIndex else {
            playSelectionEchoHaptic()
            return false
        }

        let completedTask = store.categories[categoryIndex].tasks[taskIndex]
        let completedAt = Date()
        let syncPhase = phaseForTaskSync(taskID: completedTask.id)

        withAnimation(
            lowPowerModeManager.isLowPowerModeEnabled
                ? .easeOut(duration: 0.14)
                : .spring(response: 0.3, dampingFraction: 0.8)
        ) {
            store.categories[categoryIndex].tasks[taskIndex].isComplete = true
            store.categories[categoryIndex].tasks[taskIndex].completedAt = completedAt
        }
        taskSyncStore.recordCompletion(
            taskID: completedTask.id,
            title: completedTask.title,
            categoryID: store.categories[categoryIndex].id,
            phase: syncPhase,
            completedAt: completedAt
        )
        collaborationEngine.registerLocalCompletion(
            taskID: completedTask.id,
            title: completedTask.title,
            categoryID: store.categories[categoryIndex].id,
            isTier1Urgent: syncPhase == 1,
            completedAt: completedAt
        )

        StreakManager.shared.recordTaskCompletion()
        completionStreak = StreakManager.shared.currentStreak
        registerAdEvent(.taskToggled)
        store.persistProgress()
        Task {
            await NotificationManager.shared.refreshTaskReminders(
                categories: store.categories
            )
        }

        showToast(HomeLocalization.taskMarkedCompleteToast)
        return true
    }

    @MainActor
    private func playSelectionEchoHaptic() {
        Haptics.selectionIfAllowed()
        Task { @MainActor in
            try? await Task.sleep(for: AppTiming.hapticEchoDelay)
            guard !Task.isCancelled else { return }
            Haptics.selectionIfAllowed()
        }
    }

    @MainActor
    private func openTodayTask(_ context: TodayTaskContext) {
        _ = openTaskGuide(taskID: context.task.id, preferredCategoryID: context.category.id)
    }

    @MainActor
    private func markHomeLaunchAnimationConsumedIfNeeded() {
        guard !hasLaunchedBefore else { return }
        Task { @MainActor in
            try? await Task.sleep(for: AppTiming.markHomeLaunchConsumedDelay)
            guard !Task.isCancelled else { return }
            hasLaunchedBefore = true
        }
    }

    @MainActor
    private func openCategory(at index: Int) {
        guard store.categories.indices.contains(index) else {
            LaunchMetrics.mark(event: "open_category_blocked_missing_category")
            return
        }
        let category = store.categories[index]
        guard !category.tasks.isEmpty else {
            LaunchMetrics.mark(event: "open_category_blocked_empty_tasks_\(category.id)")
            return
        }
        guard !isCategoryOverlayPresented else { return }
        clearPendingTaskGuideRequest()
        Haptics.softImpactIfAllowed()
        withAnimation(
            prefersReducedMotion
                ? .easeInOut(duration: 0.20)
                : .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
        ) {
            selectedCategoryIndex = index
        }
    }

    @MainActor
    private func closeCategoryDetail() {
        clearPendingTaskGuideRequest()
        withAnimation(
            prefersReducedMotion
                ? .easeInOut(duration: 0.18)
                : .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
        ) {
            selectedCategoryIndex = nil
        }
    }

    @MainActor
    private func clearPendingTaskGuideRequest() {
        pendingTaskGuideCategoryID = nil
        pendingTaskGuideTaskID = nil
        collaborationEngine.publishViewing(taskID: nil)
        clearColdStartTaskSnapshot()
    }

    @MainActor
    @discardableResult
    private func openTaskGuide(taskID: String, preferredCategoryID: String? = nil) -> Bool {
        guard let categoryIndex = categoryIndexForTaskGuide(taskID: taskID, preferredCategoryID: preferredCategoryID) else {
            clearPendingTaskGuideRequest()
            CrashReporter.log("task guide route failed taskID=\(taskID)", level: .warning)
            return false
        }

        if activeModal != nil {
            withAnimation(Motion.modalDismiss(prefersReducedMotion: prefersReducedMotion)) {
                activeModal = nil
            }
        }

        let categoryID = store.categories[categoryIndex].id
        pendingTaskGuideCategoryID = categoryID
        pendingTaskGuideTaskID = taskID
        collaborationEngine.publishViewing(taskID: taskID)
        persistColdStartTaskSnapshot(taskID: taskID, categoryID: categoryID)
        registerAdEvent(.taskDetailOpened)
        Haptics.softImpactIfAllowed()

        withAnimation(
            prefersReducedMotion
                ? .easeInOut(duration: 0.20)
                : .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
        ) {
            selectedCategoryIndex = categoryIndex
        }
        return true
    }

    private func categoryIndexForTaskGuide(taskID: String, preferredCategoryID: String?) -> Int? {
        if let preferredCategoryID,
           let preferredCategoryIndex = store.categories.firstIndex(where: { category in
               category.id == preferredCategoryID &&
               category.tasks.contains(where: { $0.id == taskID })
           }) {
            return preferredCategoryIndex
        }

        return store.categories.firstIndex(where: { category in
            category.tasks.contains(where: { $0.id == taskID })
        })
    }

    @MainActor
    private func ensureRenderableState(reason: String) {
        if store.categories.isEmpty {
            store.primeWithSampleDataIfNeeded()
            LaunchMetrics.mark(event: "render_state_recovered_prime_\(reason)")
        }

        if !hasCompletedInitialBootstrap && !store.categories.isEmpty {
            hasCompletedInitialBootstrap = true
            LaunchMetrics.mark(event: "render_state_recovered_unblock_\(reason)")
        }
    }

    @MainActor
    private func armBootstrapWatchdogIfNeeded() {
        bootstrapWatchdogTask?.cancel()
        bootstrapWatchdogTask = Task(priority: .utility) {
            try? await Task.sleep(for: AppTiming.bootstrapWatchdogDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !hasCompletedInitialBootstrap else { return }
                store.primeWithSampleDataIfNeeded()
                hasCompletedInitialBootstrap = true
                LaunchMetrics.mark(event: "bootstrap_watchdog_forced_unblock")
                CrashReporter.log("bootstrap watchdog forced fallback content", level: .warning)
            }
        }
    }

    @MainActor
    private func presentAdDisclosureIfNeeded() {
        guard AdRuntime.isAdsEnabledForCurrentBuild else { return }
        guard AdPreferencesStore.shared.needsInitialDisclosure else { return }
        guard activeModal == nil else { return }
        guard !isCategoryOverlayPresented else { return }

        withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
            activeModal = .adPrivacy
        }
    }

    @MainActor
    private func startHomeClockTickerIfNeeded() {
        guard minuteTickerTask == nil else { return }

        minuteTickerTask = Task(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(for: AppTiming.homeClockTickInterval)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    homeClock = Date()
                }
            }
        }
    }

    @MainActor
    private func refreshHomeContext() async {
        homeClock = Date()
        store.updateTaskViewDates()
        ArrivalWidgetSupport.syncSnapshot(categories: store.categories)
    }

    private func heroID(for index: Int) -> String {
        guard store.categories.indices.contains(index) else {
            return "category-invalid-\(index)"
        }

        let category = store.categories[index]
        let orderSegment = category.order.map(String.init) ?? "na"
        return "category-\(index)-\(category.id)-\(orderSegment)"
    }

    private func scenePhaseLabel(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }

    private func modalHeightRatio(for modal: ActiveModal) -> CGFloat {
        switch modal {
        case .search:
            return 0.86
        case .addTask(_):
            return 0.32
        case .scanQR:
            return 0.84
        case .adPrivacy:
            return 0.70
        case .help:
            return 0.65
        case .emergencyContacts:
            return 0.78
        case .privacyInfo:
            return 0.70
        case .taskDetail:
            return 0.80
        }
    }

    private func modalMinHeightRatio(for modal: ActiveModal) -> CGFloat {
        switch modal {
        case .addTask(_):
            return 0.22
        case .scanQR:
            return 0.62
        default:
            return 0.45
        }
    }

    @ViewBuilder
    private func modalView(for modal: ActiveModal) -> some View {
        switch modal {
        case .search:
            TaskSearchSheet(
                categories: store.categories,
                city: profileStore.city,
                university: profileStore.selectedUniversity,
                onSelectTask: { result in
                    _ = openTaskGuide(
                        taskID: result.task.id,
                        preferredCategoryID: result.categoryID
                    )
                },
                onClose: dismissActiveModal
            )
        case .addTask(let defaultCategoryID):
            SmartAddSheet(
                categories: $store.categories,
                fallbackCategoryID: defaultCategoryID
                    ?? store.categories.first(where: { $0.id == "before_arrival" })?.id
                    ?? store.categories.first?.id
                    ?? "before_arrival",
                onTaskAdded: { categoryTitle, taskTitle in
                    registerAdEvent(.personalTaskAdded)
                    store.persistProgress()
                    Task {
                        await NotificationManager.shared.refreshTaskReminders(
                            categories: store.categories
                        )
                    }
                    showToast(
                        HomeLocalization.quickAddSavedToast(
                            taskTitle: taskTitle,
                            categoryTitle: categoryTitle
                        )
                    )
                },
                onClose: dismissActiveModal
            )
        case .scanQR:
            StudentDiscountQRScannerSheet(
                onClose: dismissActiveModal,
                onOpenURL: { scannedURL in
                    dismissActiveModal()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeWebURL = scannedURL
                    }
                }
            )
        case .adPrivacy:
            AdPrivacySheet(preferences: AdPreferencesStore.shared, onClose: dismissActiveModal)
        case .help:
            HelpSheet(
                onOpenAdPrivacy: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .adPrivacy
                    }
                },
                onOpenEmergencyContacts: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .emergencyContacts
                    }
                },
                onOpenPrivacy: {
                    withAnimation(Motion.modalAppear(prefersReducedMotion: prefersReducedMotion)) {
                        activeModal = .privacyInfo
                    }
                },
                onClose: dismissActiveModal
            )
        case .emergencyContacts:
            EmergencyContactsSheet(onClose: dismissActiveModal)
        case .privacyInfo:
            PrivacyInfoSheet(onClose: dismissActiveModal)
        case .taskDetail(let task):
            TaskDetailSheet(
                task: task,
                onClose: dismissActiveModal,
                onMarkTaskComplete: { taskID in
                    markTaskCompleteFromDetail(taskID: taskID)
                }
            )
        }
    }

    private enum ActiveModal: Identifiable {
        case search
        case addTask(defaultCategoryID: String?)
        case scanQR
        case adPrivacy
        case help
        case emergencyContacts
        case privacyInfo
        case taskDetail(ChecklistTask)

        var id: String {
            switch self {
            case .search:
                return "search"
            case .addTask(let defaultCategoryID):
                if let defaultCategoryID, !defaultCategoryID.isEmpty {
                    return "add-task-\(defaultCategoryID)"
                }
                return "add-task"
            case .scanQR:
                return "scan-qr"
            case .adPrivacy:
                return "ad-privacy"
            case .help:
                return "help"
            case .emergencyContacts:
                return "emergency-contacts"
            case .privacyInfo:
                return "privacy-info"
            case .taskDetail(let task):
                return "task-\(task.id)"
            }
        }
    }

    private enum ActiveSheet: Identifiable {
        case search
        case addTask(defaultCategoryID: String?)
        case scanQR
        case adPrivacy
        case help
        case taskDetail(ChecklistTask)
        case profileSetup
        case web(URL)

        var id: String {
            switch self {
            case .search:
                return "search"
            case .addTask(let defaultCategoryID):
                if let defaultCategoryID, !defaultCategoryID.isEmpty {
                    return "add-task-\(defaultCategoryID)"
                }
                return "add-task"
            case .scanQR:
                return "scan-qr"
            case .adPrivacy:
                return "ad-privacy"
            case .help:
                return "help"
            case .taskDetail(let task):
                return "task-\(task.id)"
            case .profileSetup:
                return "profile-setup"
            case .web(let url):
                return "web-\(url.absoluteString)"
            }
        }
    }

}

private extension View {
    @ViewBuilder
    func phase12VisionOrnament(
        onHomeTap: @escaping () -> Void,
        onWalletTap: @escaping () -> Void,
        onQuickTaskTap: @escaping () -> Void
    ) -> some View {
        #if os(visionOS)
        ornament(attachmentAnchor: .scene(.leading), contentAlignment: .center) {
            Phase12VisionOrnamentRail(
                onHomeTap: onHomeTap,
                onWalletTap: onWalletTap,
                onQuickTaskTap: onQuickTaskTap
            )
            .padding(8)
            .glassBackgroundEffect()
        }
        #else
        self
        #endif
    }
}

#if os(visionOS)
private struct Phase12VisionOrnamentRail: View {
    let onHomeTap: () -> Void
    let onWalletTap: () -> Void
    let onQuickTaskTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ornamentButton(
                systemImage: "house.fill",
                label: "Home",
                action: onHomeTap
            )
            ornamentButton(
                systemImage: "wallet.pass.fill",
                label: "Wallet",
                action: onWalletTap
            )
            ornamentButton(
                systemImage: "checklist.checked",
                label: "Quick Task",
                action: onQuickTaskTap
            )
        }
    }

    private func ornamentButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(label)
    }
}
#endif
