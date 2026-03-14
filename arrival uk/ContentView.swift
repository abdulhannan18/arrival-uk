import SwiftUI
import UIKit
import os
import AuthenticationServices
import SafariServices
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ContentStore()
    @State private var adCoordinator = AdCoordinator()
    @State private var profileStore = StudentProfileStore.shared
    @State private var activeSheet: ActiveSheet?
    @State private var enableDecorativeEffects = false

    init() {
        LaunchMetrics.mark(event: "content_view_init")
    }

    private var stats: ChecklistStats {
        ChecklistStats(categories: store.categories)
    }

    private var prefersConservativeVisuals: Bool {
        PerformanceProfile.prefersConservativeVisuals
    }

    private var timelinePrimaryMetric: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let arrivalDay = calendar.startOfDay(for: profileStore.arrivalDate)
        let deltaDays = calendar.dateComponents([.day], from: today, to: arrivalDay).day ?? 0

        if deltaDays > 0 {
            let suffix = deltaDays == 1 ? "day" : "days"
            return "\(deltaDays) \(suffix) until arrival"
        }

        if deltaDays == 0 {
            return "Arrival day in UK"
        }

        let daysSinceArrival = abs(deltaDays)
        return "Day \(daysSinceArrival) in UK"
    }

    private var visibleCategoryIndices: [Int] {
        store.categories.indices.filter { index in
            let category = store.categories[index]
            guard category.isVisible else { return false }
            return category.matchesAudience(
                city: profileStore.city,
                university: profileStore.selectedUniversity
            )
        }
    }

    private func spacingAfterCategory(at position: Int, in orderedIndices: [Int]) -> CGFloat {
        guard position < orderedIndices.count - 1 else { return Theme.spaceM }
        let priority = store.categories[orderedIndices[position]].visualPriority
        switch priority {
        case .critical, .high:
            return 16
        case .medium, .low:
            return 12
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    HeaderView(
                        primaryMetric: timelinePrimaryMetric,
                        profileActionTitle: profileStore.hasCompletedSetup ? "Manage profile" : "Set up profile",
                        onProfileTap: {
                            activeSheet = .profileSetup
                        }
                    )
                    .padding(.bottom, Theme.spaceXXL)

                    let orderedIndices = visibleCategoryIndices
                    ForEach(Array(orderedIndices.enumerated()), id: \.element) { position, index in
                        Group {
                            CategoryCard(
                                category: $store.categories[index],
                                useDecorativeEffects: enableDecorativeEffects,
                                onOpenTask: { task in
                                    registerAdEvent(.taskDetailOpened)
                                    activeSheet = .taskDetail(task)
                                }
                            )
                        }
                        .padding(.bottom, spacingAfterCategory(at: position, in: orderedIndices))
                    }

                    Button {
                        activeSheet = .addTask
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Add Personal Task")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.inverseText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.spaceL)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                .fill(Theme.primaryButtonBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, Theme.spaceM)

                    Button {
                        activeSheet = .adPrivacy
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.shield.fill")
                            Text("Ad & Privacy Settings")
                                .font(.system(.callout, weight: .semibold))
                        }
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spaceS)
                        .cardChrome(elevated: false)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.spaceXL)
                .padding(.top, Theme.spaceL)
                .padding(.bottom, Theme.bottomBarReserve)
            }
            .background(
                Theme.background(
                    for: colorScheme,
                    conservative: prefersConservativeVisuals
                )
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom) {
                FloatingGlassNavBar()
            }
            .navigationBarHidden(true)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addTask:
                    AddTaskSheet(
                        categories: $store.categories,
                        onTaskAdded: {
                            registerAdEvent(.personalTaskAdded)
                        }
                    )
                case .adPrivacy:
                    AdPrivacySheet(preferences: AdPreferencesStore.shared)
                case .taskDetail(let task):
                    TaskDetailSheet(task: task)
                case .profileSetup:
                    ProfileSetupSheet(store: profileStore)
                case .web(let url):
                    InAppBrowserSheet(url: url)
                }
            }
            .environment(\.openURL, OpenURLAction { url in
                handleOpenURL(url)
            })
            .onOpenURL { url in
                if GoogleSignInBridge.handle(url: url) {
                    return
                }

                guard let scheme = url.scheme?.lowercased() else { return }
                if scheme == "http" || scheme == "https" {
                    activeSheet = .web(url)
                }
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    AdRuntime.updateConsentConfiguration()
                    registerAdEvent(.appBecameActive)
                }
            }
            .onChange(of: store.categories) { _, _ in
                store.persistProgress()
            }
            .task {
                LaunchMetrics.mark(event: "content_view_task_begin")
                AdRuntime.bootstrapIfNeeded()
                adCoordinator.startSessionIfNeeded()
                profileStore.bootstrapIfNeeded()
                await loadContentIfNeeded()
                LaunchMetrics.mark(event: "content_loaded_in_view")
                await enableEffectsAfterFirstFrame()
                if !profileStore.hasCompletedSetup {
                    activeSheet = .profileSetup
                }
            }
        }
    }

    @MainActor
    private func loadContentIfNeeded() async {
        guard store.categories.isEmpty else { return }
        store.loadFromBundle()
    }

    @MainActor
    private func enableEffectsAfterFirstFrame() async {
        guard !enableDecorativeEffects else { return }

        guard !prefersConservativeVisuals else {
            LaunchMetrics.mark(event: "decorative_effects_skipped_conservative_mode")
            return
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        enableDecorativeEffects = true
        LaunchMetrics.mark(event: "decorative_effects_enabled")
    }

    @MainActor
    private func registerAdEvent(_ event: AdEvent) {
        if let opportunity = adCoordinator.register(event: event) {
            AdRuntime.requestAd(for: opportunity)
        }
    }

    private enum ActiveSheet: Identifiable {
        case addTask
        case adPrivacy
        case taskDetail(ChecklistTask)
        case profileSetup
        case web(URL)

        var id: String {
            switch self {
            case .addTask:
                return "add-task"
            case .adPrivacy:
                return "ad-privacy"
            case .taskDetail(let task):
                return "task-\(task.id)"
            case .profileSetup:
                return "profile-setup"
            case .web(let url):
                return "web-\(url.absoluteString)"
            }
        }
    }

    @MainActor
    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if GoogleSignInBridge.handle(url: url) {
            return .handled
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .systemAction
        }

        if scheme == "http" || scheme == "https" {
            registerAdEvent(.resourceOpened)
            activeSheet = .web(url)
            return .handled
        }

        return .systemAction
    }
}

private struct InAppBrowserSheet: View {
    let url: URL

    var body: some View {
        InAppBrowserView(url: url)
            .ignoresSafeArea()
    }
}

private struct InAppBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct GoogleSignInIdentity {
    let userID: String
    let email: String
    let fullName: String?
}

private enum GoogleSignInBridgeError: LocalizedError {
    case sdkNotLinked
    case missingClientID
    case missingReversedClientID
    case missingURLScheme(String)
    case missingPresenter
    case missingEmail
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sdkNotLinked:
            return "Google Sign-In SDK is not linked in this build."
        case .missingClientID:
            return "Google client ID is missing. Add GoogleService-Info.plist first."
        case .missingReversedClientID:
            return "Google reversed client ID is missing. Ensure GoogleService-Info.plist contains REVERSED_CLIENT_ID."
        case .missingURLScheme(let scheme):
            return "Missing URL scheme '\(scheme)' in app Info settings. Add it to URL Types so Google can return to the app."
        case .missingPresenter:
            return "Could not find an active screen to present Google Sign-In."
        case .missingEmail:
            return "Google account did not return an email."
        case .cancelled:
            return "Google Sign-In was cancelled."
        }
    }
}

@MainActor
private enum GoogleSignInBridge {
    static var isSDKLinked: Bool {
        #if canImport(GoogleSignIn)
        return true
        #else
        return false
        #endif
    }

    static func handle(url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    static func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    static func signIn(presenting: UIViewController?) async throws -> GoogleSignInIdentity {
        #if canImport(GoogleSignIn)
        guard let presenting else {
            throw GoogleSignInBridgeError.missingPresenter
        }

        guard let clientID = readClientID() else {
            throw GoogleSignInBridgeError.missingClientID
        }
        guard let reversedClientID = readReversedClientID() else {
            throw GoogleSignInBridgeError.missingReversedClientID
        }
        guard hasURLScheme(reversedClientID) else {
            throw GoogleSignInBridgeError.missingURLScheme(reversedClientID)
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let email = result.user.profile?.email else {
                throw GoogleSignInBridgeError.missingEmail
            }

            return GoogleSignInIdentity(
                userID: result.user.userID ?? email.lowercased(),
                email: email.lowercased(),
                fullName: result.user.profile?.name
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
                throw GoogleSignInBridgeError.cancelled
            }
            throw error
        }
        #else
        throw GoogleSignInBridgeError.sdkNotLinked
        #endif
    }

    private static func readClientID() -> String? {
        if let infoClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !infoClientID.isEmpty {
            return infoClientID
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let clientID = plist["CLIENT_ID"] as? String,
            !clientID.isEmpty
        else {
            return nil
        }

        return clientID
    }

    private static func readReversedClientID() -> String? {
        if
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            !urlTypes.isEmpty
        {
            for entry in urlTypes {
                if let schemes = entry["CFBundleURLSchemes"] as? [String] {
                    for scheme in schemes where !scheme.isEmpty {
                        if scheme.contains("com.googleusercontent.apps.") {
                            return scheme
                        }
                    }
                }
            }
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let reversed = plist["REVERSED_CLIENT_ID"] as? String,
            !reversed.isEmpty
        else {
            return nil
        }

        return reversed
    }

    private static func hasURLScheme(_ expectedScheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for entry in urlTypes {
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in schemes where scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame {
                return true
            }
        }

        return false
    }
}

@MainActor
private enum PresentationAnchor {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard
            let window = activeScene?.windows.first(where: \.isKeyWindow),
            let root = window.rootViewController
        else {
            return nil
        }

        return topMostViewController(from: root)
    }

    private static func topMostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }

        if let navigation = root as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }

        if let tabBar = root as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return topMostViewController(from: selected)
        }

        return root
    }
}

private struct TaskContext: Hashable {
    let category: ChecklistCategory
    let task: ChecklistTask
    let stepIndex: Int
    let totalSteps: Int
}

private enum CategoryPriorityLevel: String, Codable, CaseIterable, Hashable {
    case critical
    case high
    case medium
    case low

    var ranking: Int {
        switch self {
        case .critical:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }

    static func fromLegacy(priority: Int) -> CategoryPriorityLevel {
        switch priority {
        case ..<2:
            return .critical
        case 2:
            return .high
        case 3:
            return .medium
        default:
            return .low
        }
    }
}

private enum CategoryUrgencyBand: String, Codable, Hashable {
    case immediate
    case week1
    case week2
    case anytime
    case completed

    var ranking: Int {
        switch self {
        case .immediate:
            return 0
        case .week1:
            return 1
        case .week2:
            return 2
        case .anytime:
            return 3
        case .completed:
            return 4
        }
    }
}

private enum CategoryAccentStyle: Hashable {
    case gradient
    case solidBorder
    case tintedBackground
    case icon
}

private enum CategoryShadowLevel: Hashable {
    case none
    case subtle
    case medium
    case elevated
}

private struct CategoryVisualStyle: Hashable {
    let minHeight: CGFloat
    let cornerRadius: CGFloat
    let titleFontSize: CGFloat
    let titleWeight: Font.Weight
    let titleTracking: CGFloat
    let subtitleFontSize: CGFloat
    let subtitleWeight: Font.Weight
    let subtitleOpacity: Double
    let metaFontSize: CGFloat
    let iconSize: CGFloat
    let borderWidth: CGFloat
    let accentStyle: CategoryAccentStyle
    let shadowLevel: CategoryShadowLevel
    let cardPadding: CGFloat
}

private enum CategoryVisualHierarchy {
    private static let styles: [CategoryPriorityLevel: CategoryVisualStyle] = [
        .critical: CategoryVisualStyle(
            minHeight: 200,
            cornerRadius: 24,
            titleFontSize: 28,
            titleWeight: .bold,
            titleTracking: -0.5,
            subtitleFontSize: 14,
            subtitleWeight: .regular,
            subtitleOpacity: 0.80,
            metaFontSize: 14,
            iconSize: 56,
            borderWidth: 0,
            accentStyle: .gradient,
            shadowLevel: .elevated,
            cardPadding: 24
        ),
        .high: CategoryVisualStyle(
            minHeight: 140,
            cornerRadius: 24,
            titleFontSize: 22,
            titleWeight: .bold,
            titleTracking: -0.3,
            subtitleFontSize: 12,
            subtitleWeight: .regular,
            subtitleOpacity: 0.85,
            metaFontSize: 12,
            iconSize: 44,
            borderWidth: 0,
            accentStyle: .solidBorder,
            shadowLevel: .medium,
            cardPadding: 20
        ),
        .medium: CategoryVisualStyle(
            minHeight: 120,
            cornerRadius: 20,
            titleFontSize: 20,
            titleWeight: .semibold,
            titleTracking: 0,
            subtitleFontSize: 11,
            subtitleWeight: .regular,
            subtitleOpacity: 0.70,
            metaFontSize: 11,
            iconSize: 40,
            borderWidth: 0,
            accentStyle: .tintedBackground,
            shadowLevel: .subtle,
            cardPadding: 16
        ),
        .low: CategoryVisualStyle(
            minHeight: 100,
            cornerRadius: 20,
            titleFontSize: 18,
            titleWeight: .semibold,
            titleTracking: 0,
            subtitleFontSize: 12,
            subtitleWeight: .regular,
            subtitleOpacity: 0.80,
            metaFontSize: 11,
            iconSize: 36,
            borderWidth: 0,
            accentStyle: .icon,
            shadowLevel: .subtle,
            cardPadding: 16
        )
    ]

    static func getVisualStyle(_ priority: CategoryPriorityLevel) -> CategoryVisualStyle {
        styles[priority] ?? styles[.medium]!
    }
}

private struct HeaderView: View {
    let primaryMetric: String
    let profileActionTitle: String
    let onProfileTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack(alignment: .firstTextBaseline) {
                Text("Arrival UK")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .tracking(-0.3)

                Spacer()

                Button(action: onProfileTap) {
                    Text("\(profileActionTitle) ->")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.linkText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Text(primaryMetric)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.spaceL)
        .padding(.bottom, Theme.spaceXXXL)
    }
}

private struct HeroTaskCard: View {
    let context: TaskContext
    let useDecorativeEffects: Bool
    let onContinue: () -> Void

    private var palette: CategoryPalette {
        Theme.palette(for: context.category)
    }

    private var completedSteps: Int {
        max(context.stepIndex - 1, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            Text("NEXT STEP")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .tracking(0.6)

            HStack(alignment: .top, spacing: Theme.spaceS) {
                IconBadge(
                    systemName: context.category.icon,
                    tint: Theme.accentColor(for: context.category),
                    size: 46
                )

                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    Text(context.category.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .tracking(0.8)

                    Text(context.task.title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    if let detail = context.task.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                    }
                }
            }

            SegmentedPillProgress(
                completedCount: completedSteps,
                currentIndex: completedSteps,
                totalCount: context.totalSteps,
                accentColor: Theme.accentColor(for: context.category)
            )

            Text("Step \(context.stepIndex) of \(context.totalSteps) • \(context.task.timing.label)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Button(action: onContinue) {
                HStack {
                    Text("Continue This")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.spaceM)
                .padding(.vertical, Theme.spaceS)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                LuxuryPrimaryButtonStyle()
            )
        }
        .padding(Theme.spaceL)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.gradient.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.gradient.opacity(0.34), lineWidth: 1.1)
        )
        .shadow(
            color: useDecorativeEffects ? palette.shadowColor.opacity(0.18) : .clear,
            radius: 24,
            x: 0,
            y: 12
        )
    }
}

private struct ComingUpSection: View {
    let tasks: [TaskContext]
    let onOpenTask: (ChecklistTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            Text("COMING UP")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .tracking(0.6)

            ForEach(tasks, id: \.task.id) { context in
                Button {
                    onOpenTask(context.task)
                } label: {
                    HStack(spacing: Theme.spaceS) {
                        IconBadge(
                            systemName: context.category.icon,
                            tint: Theme.accentColor(for: context.category),
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.task.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                            Text("\(context.task.timing.label) • \(context.category.title)")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(Theme.spaceM)
                    .cardChrome(elevated: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HeaderPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.accent.opacity(0.36), lineWidth: 1)
        )
        .shadow(
            color: Theme.accent.opacity(0.14),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

private struct HeaderMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.track.opacity(0.85))
        )
    }
}

private struct ProfileOverviewCard: View {
    let profileStore: StudentProfileStore
    let onManageProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack {
                Text("STUDENT PROFILE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .tracking(0.6)
                Spacer()
                Button("Manage", action: onManageProfile)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            if profileStore.hasCompletedSetup {
                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    HStack {
                        Text(profileStore.fullName.isEmpty ? "Student" : profileStore.fullName)
                            .font(.system(.headline, weight: .semibold))
                        Spacer()
                        ProfileProviderBadge(provider: profileStore.authProvider)
                    }

                    if !profileStore.selectedUniversity.isEmpty {
                        Text(profileStore.selectedUniversity)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack(spacing: Theme.spaceS) {
                        if !profileStore.courseName.isEmpty {
                            TaskMetaBadge(title: profileStore.courseName)
                        }
                        TaskMetaBadge(title: profileStore.studyLevel.label)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    Text("Complete your profile to personalize timelines and recommendations.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)

                    Button(action: onManageProfile) {
                        Text("Set Up Profile")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Theme.primaryButtonBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.spaceM)
        .cardChrome(elevated: false)
    }
}

private struct ProfileProviderBadge: View {
    let provider: StudentAuthProvider

    var body: some View {
        Text(provider.label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.track)
            )
    }
}

private struct CircularProgressBadge: View {
    let progress: Double
    let useDecorativeEffects: Bool

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 9)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Theme.accent,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(clampedProgress * 100))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(width: 80, height: 80)
        .background(
            Circle()
                .fill(Theme.card.opacity(0.75))
        )
        .shadow(
            color: useDecorativeEffects ? Theme.accent.opacity(0.18) : .clear,
            radius: 10,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overall progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }
}

private struct LuxuryPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Theme.spaceM)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .fill(configuration.isPressed ? Theme.primaryButtonPressed : Theme.primaryButtonBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: Theme.shadowMedium,
                radius: 8,
                x: 0,
                y: 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct CategoryCard: View {
    @Binding var category: ChecklistCategory
    let useDecorativeEffects: Bool
    let onOpenTask: (ChecklistTask) -> Void

    private var stats: CategoryStats {
        CategoryStats(tasks: category.tasks)
    }

    private var visualStyle: CategoryVisualStyle {
        CategoryVisualHierarchy.getVisualStyle(category.visualPriority)
    }

    private var accentColor: Color {
        Theme.categoryBackground(for: category)
    }

    private var cardTextColor: Color {
        Theme.categoryText(for: category)
    }

    private var firstActionTask: ChecklistTask? {
        category.tasks.first(where: { !$0.isComplete }) ?? category.tasks.first
    }

    private var shouldShowProgress: Bool {
        stats.totalCount > 0 && stats.completedCount > 0 && stats.completedCount < stats.totalCount
    }

    private var metaLine: String {
        var chunks: [String] = []
        if stats.totalCount == 0 {
            chunks.append("No tasks yet")
        } else if stats.completedCount == stats.totalCount {
            let taskWord = stats.totalCount == 1 ? "task" : "tasks"
            chunks.append("Completed \(stats.totalCount) \(taskWord)")
        } else {
            let taskWord = stats.totalCount == 1 ? "task" : "tasks"
            chunks.append("\(stats.completedCount)/\(stats.totalCount) \(taskWord)")
        }

        if let dueLabel = category.deadlineLabel {
            chunks.append("Due \(dueLabel)")
        }

        return chunks.joined(separator: " • ")
    }

    private var ctaLabel: String {
        if stats.totalCount == 0 { return "Open Category" }
        if stats.completedCount == 0 { return "Start Category" }
        if stats.completedCount == stats.totalCount { return "Review Category" }
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

    private var usesDarkForeground: Bool {
        Theme.categoryUsesDarkForeground(for: category)
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
        VStack(alignment: .leading, spacing: max(10, visualStyle.cardPadding * 0.34)) {
            HStack(spacing: Theme.spaceS) {
                Text(urgencyLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.categoryBadgeText(for: category))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.categoryBadgeBackground(for: category))
                    )

                Spacer()

                if stats.totalCount > 0 && stats.completedCount == stats.totalCount {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.urgencyColor(.completed))
                }
            }

            HStack(spacing: Theme.spaceS) {
                IconBadge(
                    systemName: category.icon,
                    tint: cardTextColor,
                    size: visualStyle.iconSize
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .font(.system(size: visualStyle.titleFontSize, weight: visualStyle.titleWeight))
                        .tracking(visualStyle.titleTracking)
                        .foregroundStyle(cardTextColor)
                        .lineLimit(1)

                    if !category.resolvedSubtitle.isEmpty {
                        Text(category.resolvedSubtitle)
                            .font(.system(size: visualStyle.subtitleFontSize, weight: visualStyle.subtitleWeight))
                            .foregroundStyle(cardTextColor.opacity(visualStyle.subtitleOpacity))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            Text(metaLine)
                .font(.system(size: visualStyle.metaFontSize, weight: .semibold))
                .foregroundStyle(cardTextColor.opacity(0.84))

            if shouldShowProgress {
                SegmentedPillProgress(
                    completedCount: stats.completedCount,
                    currentIndex: stats.completedCount,
                    totalCount: max(stats.totalCount, 4),
                    accentColor: accentColor
                )
            }

            if let firstActionTask {
                Button {
                    onOpenTask(firstActionTask)
                } label: {
                    HStack(spacing: 8) {
                        Text(ctaLabel)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(usesDarkForeground ? Theme.navy900 : Theme.inverseText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(usesDarkForeground ? Theme.cream100 : .white.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(usesDarkForeground ? Theme.navy200 : .white.opacity(0.34), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: visualStyle.minHeight, alignment: .topLeading)
        .padding(visualStyle.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: visualStyle.cornerRadius, style: .continuous)
                .fill(Theme.categoryBackground(for: category))
        )
        .shadow(
            color: useDecorativeEffects ? shadowConfig.color : shadowConfig.color.opacity(0.75),
            radius: shadowConfig.radius,
            x: 0,
            y: shadowConfig.y
        )
    }
}

private struct BrandMark: View {
    let useDecorativeEffects: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.primaryButtonBackground)
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)

            VStack(spacing: 2) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("UK")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 58, height: 58)
        .shadow(
            color: useDecorativeEffects ? Theme.accent.opacity(0.26) : .clear,
            radius: 16,
            x: 0,
            y: 8
        )
    }
}

private struct JourneyStrip: View {
    let progress: Double
    private let stages = ["Prepare", "Arrive", "Settle", "Ready"]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceXS) {
            Text("Your journey")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                ForEach(stages.indices, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(isStageActive(index) ? Theme.accent : Theme.track)
                            .frame(
                                width: currentStageIndex == index ? 14 : 10,
                                height: currentStageIndex == index ? 14 : 10
                            )

                        if currentStageIndex == index {
                            Circle()
                                .stroke(Theme.accent.opacity(0.34), lineWidth: 4)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStageIndex)

                    if index < stages.count - 1 {
                        Rectangle()
                            .fill(isSegmentActive(index) ? Theme.accent.opacity(0.75) : Theme.track)
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                    }
                }
            }

            HStack {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    Text(stage)
                        .font(
                            .system(
                                size: currentStageIndex == index ? 12 : 11,
                                weight: currentStageIndex == index ? .bold : .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(currentStageIndex == index ? Theme.primaryText : Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Theme.spaceS)
        .cardChrome(elevated: false)
    }

    private func isStageActive(_ index: Int) -> Bool {
        guard stages.count > 1 else { return true }
        let threshold = Double(index) / Double(stages.count - 1)
        return clampedProgress >= threshold
    }

    private func isSegmentActive(_ index: Int) -> Bool {
        guard stages.count > 1 else { return false }
        let threshold = Double(index + 1) / Double(stages.count - 1)
        return clampedProgress >= threshold
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var currentStageIndex: Int {
        guard !stages.isEmpty else { return 0 }
        if clampedProgress >= 1 {
            return stages.count - 1
        }
        let scaled = Int(floor(clampedProgress * Double(stages.count)))
        return min(max(scaled, 0), stages.count - 1)
    }
}

private struct IconBadge: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 36

    var body: some View {
        Group {
            if UIImage(systemName: systemName) != nil {
                Image(systemName: systemName)
                    .font(.system(size: max(size * 0.52, 14), weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                Text(systemName)
                    .font(.system(size: max(size * 0.50, 14), weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size, alignment: .center)
        .accessibilityHidden(true)
    }
}

private struct SegmentedPillProgress: View {
    let completedCount: Int
    let currentIndex: Int
    let totalCount: Int
    let accentColor: Color

    private var effectiveTotal: Int {
        max(totalCount, 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<effectiveTotal, id: \.self) { index in
                ZStack {
                    Capsule(style: .continuous)
                        .fill(Theme.track)

                    if index < completedCount {
                        Capsule(style: .continuous)
                            .fill(accentColor)

                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    } else if index == currentIndex, completedCount < effectiveTotal {
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(0.30))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(accentColor.opacity(0.70), lineWidth: 1)
                            )
                    }
                }
                .frame(width: 40, height: 10)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: completedCount)
            }
        }
    }
}

private enum GlassMode {
    case full
    case lite
    case solid
}

private enum GlassRenderingPolicy {
    static func resolveMode(
        conservative: Bool,
        reduceTransparency: Bool
    ) -> GlassMode {
        if reduceTransparency {
            return .solid
        }
        if conservative {
            return .lite
        }
        return .full
    }
}

private struct GlassSurface: View {
    let cornerRadius: CGFloat
    let tint: Color
    var tintOpacity: Double = 0.18
    var strokeOpacity: Double = 0.22
    var highlightOpacity: Double = 0.12
    var conservative: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var mode: GlassMode {
        GlassRenderingPolicy.resolveMode(
            conservative: conservative,
            reduceTransparency: reduceTransparency
        )
    }

    private var effectiveStrokeOpacity: Double {
        if colorSchemeContrast == .increased {
            return min(strokeOpacity + 0.14, 0.6)
        }
        return strokeOpacity
    }

    private var effectiveHighlightOpacity: Double {
        if colorSchemeContrast == .increased {
            return min(highlightOpacity + 0.10, 0.42)
        }
        return highlightOpacity
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            switch mode {
            case .solid:
                shape
                    .fill(tint.opacity(max(tintOpacity, 0.92)))
            case .lite:
                shape
                    .fill(.thinMaterial)
                shape
                    .fill(tint.opacity(min(max(tintOpacity, 0), 0.22)))
            case .full:
                shape
                    .fill(.ultraThinMaterial)
                shape
                    .fill(tint.opacity(min(max(tintOpacity, 0), 0.16)))
            }
        }
        .overlay(
            shape
                .stroke(Color.white.opacity(effectiveStrokeOpacity), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            shape
                .stroke(Color.white.opacity(effectiveHighlightOpacity), lineWidth: 0.6)
                .padding(0.5)
        }
    }
}

private struct GlassBar<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color
    let conservative: Bool
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat,
        tint: Color,
        conservative: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.conservative = conservative
        self.content = content()
    }

    var body: some View {
        content
            .background {
                GlassSurface(
                    cornerRadius: cornerRadius,
                    tint: tint,
                    tintOpacity: 0.18,
                    strokeOpacity: 0.26,
                    highlightOpacity: 0.16,
                    conservative: conservative
                )
            }
    }
}

private struct FloatingGlassNavBar: View {
    var body: some View {
        GlassBar(
            cornerRadius: Theme.radiusL,
            tint: Theme.navBarBackground,
            conservative: PerformanceProfile.prefersConservativeVisuals
        ) {
            HStack(spacing: Theme.spaceS) {
                FloatingNavItem(label: "Home", icon: "house.fill", isActive: true)
                FloatingNavItem(label: "Tasks", icon: "checklist", isActive: false)
                FloatingNavItem(label: "Areas", icon: "square.grid.2x2", isActive: false)
                FloatingNavItem(label: "Help", icon: "questionmark.circle", isActive: false)
            }
            .padding(.horizontal, Theme.spaceS)
            .padding(.vertical, 9)
        }
        .shadow(color: Theme.shadowElevated, radius: 16, x: 0, y: 8)
        .padding(.horizontal, Theme.spaceL)
        .padding(.bottom, Theme.spaceXS)
    }
}

private struct FloatingNavItem: View {
    let label: String
    let icon: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Theme.navActive : Theme.tertiaryText)
            Text(label)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Theme.navActive : Theme.tertiaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(isActive ? Theme.navActiveBackground : .clear)
        )
    }
}

private struct TaskRow: View {
    @Binding var task: ChecklistTask
    let onToggleComplete: () -> Void
    let onOpenDetails: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    task.isComplete.toggle()
                }
                onToggleComplete()
                if task.isComplete {
                    Haptics.softImpactIfAllowed()
                }
            } label: {
                CheckMark(isOn: task.isComplete)
            }
            .buttonStyle(.plain)

            Button(action: onOpenDetails) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)

                        if let detail = task.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Text("\(task.priority.label) • \(task.timing.label)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 2)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.title)
            .accessibilityHint("Opens task details")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.track.opacity(task.isComplete ? 0.42 : 0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke.opacity(0.8), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct TaskMetaBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.track)
            )
    }
}

private struct TaskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: ChecklistTask

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceM) {
                    Text(task.title)
                        .font(.system(.title2, weight: .semibold))

                    HStack(spacing: 8) {
                        TaskMetaBadge(title: task.priority.label)
                        TaskMetaBadge(title: task.timing.label)

                        if let estimatedMinutes = task.estimatedMinutes, estimatedMinutes > 0 {
                            TaskMetaBadge(title: "\(estimatedMinutes) min")
                        }

                        TaskMetaBadge(title: task.urgency.label)
                    }

                    if let detail = task.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let content = task.content, !content.sections.isEmpty {
                        TaskContentRenderer(sections: content.sections)
                    } else {
                        if let sourceTitle = task.sourceTitle, !sourceTitle.isEmpty {
                            Text("Source")
                                .font(.headline)
                                .padding(.top, 6)

                            if let sourceURL = task.sourceURL, let url = URL(string: sourceURL) {
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                        Text(sourceTitle)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.body.weight(.medium))
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Theme.card)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Theme.stroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(sourceTitle)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .glassSheetPresentation(conservative: PerformanceProfile.prefersConservativeVisuals)
    }
}

private struct TaskContentRenderer: View {
    let sections: [ContentSection]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ContentSection) -> some View {
        switch section {
        case .why(let value):
            TaskSectionCard(title: value.title ?? "Why this matters", icon: value.icon ?? "lightbulb.fill") {
                Text(value.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        case .overview(let value):
            TaskSectionCard(title: value.title ?? "Overview", icon: "text.alignleft") {
                Text(value.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        case .checklist(let value):
            TaskSectionCard(title: value.title ?? "Checklist", icon: "checklist") {
                VStack(alignment: .leading, spacing: Theme.spaceXS) {
                    ForEach(value.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                                .font(.system(size: 14))
                                .padding(.top, 2)
                            Text(item)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case .options(let value):
            TaskOptionsSectionView(title: value.title ?? "Options", options: value.items)
        case .comparisonTable(let value):
            TaskOptionsSectionView(title: value.title ?? "Comparison", options: value.items)
        case .tips(let value):
            TaskSectionCard(title: value.title ?? "Tips", icon: "sparkles") {
                VStack(alignment: .leading, spacing: Theme.spaceS) {
                    ForEach(Array(value.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\"\(item.text)\"")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            if let author = item.author, !author.isEmpty {
                                Text(author)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        case .references(let value):
            TaskReferencesSectionView(title: value.title ?? "References", items: value.items)
        case .officialReferences(let value):
            TaskReferencesSectionView(title: value.title ?? "Official resources", items: value.items)
        case .steps(let value):
            TaskStepsSectionView(title: value.title ?? "Step-by-step", steps: value.items)
        case .apps(let value):
            TaskAppsSectionView(title: value.title ?? "Helpful apps", items: value.items)
        case .faqs(let value):
            TaskFAQSectionView(title: value.title ?? "Common questions", items: value.items)
        case .unsupported(let value):
            TaskUnsupportedSectionView(section: value)
        }
    }
}

private struct TaskSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack(spacing: 8) {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(icon)
                }

                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(Theme.spaceM)
        .cardChrome(elevated: false)
    }
}

private struct SourceMetadataLine: View {
    let source: SourceMetadata

    private var tone: Color {
        Theme.sourceTint(for: source.resolvedTrustType)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(source.resolvedTrustType.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tone)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(tone.opacity(0.12))
                )

            if let sourceName = source.sourceName, !sourceName.isEmpty {
                Text(sourceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let verifiedLabel = source.verifiedLabel {
                Text("Verified \(verifiedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct TaskOptionsSectionView: View {
    let title: String
    let options: [OptionItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "tablecells") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    VStack(alignment: .leading, spacing: Theme.spaceXS) {
                        HStack {
                            Text(option.name)
                                .font(.system(.body, weight: .semibold))
                            Spacer()
                            if let price = option.priceLevel {
                                Text(price)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let description = option.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let rating = option.rating {
                            Text("Rating: \(String(format: "%.1f", rating))/5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let source = option.source ?? option.link?.source {
                            SourceMetadataLine(source: source)
                        }

                        if !option.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(option.highlights, id: \.self) { highlight in
                                    Text("• \(highlight)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack(spacing: Theme.spaceXS) {
                            if let linkURL = option.link?.resolvedURL {
                                Link(destination: linkURL) {
                                    Label(option.link?.label ?? "Open Link", systemImage: "arrow.up.right.square")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Theme.track)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            if let mapsURL = option.location?.mapsURL {
                                Link(destination: mapsURL) {
                                    Label("Find Nearby", systemImage: "location")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Theme.track)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(Theme.spaceS)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                            .fill(Theme.track.opacity(0.6))
                    )
                }
            }
        }
    }
}

private struct TaskReferencesSectionView: View {
    let title: String
    let items: [ReferenceItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "link") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    if let url = URL(string: item.url) {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(item.title)
                                    .font(.footnote.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let source = item.resolvedSourceMetadata {
                        SourceMetadataLine(source: source)
                    }
                }
            }
        }
    }
}

private struct TaskStepsSectionView: View {
    let title: String
    let steps: [ProcessStepItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "list.number") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    VStack(alignment: .leading, spacing: Theme.spaceXS) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(step.number).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                            Text(step.title)
                                .font(.footnote.weight(.semibold))
                        }

                        if let description = step.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !step.requirements.isEmpty {
                            ForEach(step.requirements, id: \.self) { requirement in
                                Text("• \(requirement)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !step.actions.isEmpty {
                            HStack(spacing: Theme.spaceXS) {
                                ForEach(Array(step.actions.enumerated()), id: \.offset) { _, action in
                                    if let actionURL = action.resolvedURL {
                                        Link(destination: actionURL) {
                                            Text(action.label)
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(Theme.track)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.spaceS)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                            .fill(Theme.track.opacity(0.55))
                    )
                }
            }
        }
    }
}

private struct TaskAppsSectionView: View {
    let title: String
    let items: [AppRecommendationItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.footnote.weight(.semibold))
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let targetURL = item.downloadLinks?.primaryURL {
                            Link("Open", destination: targetURL)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }
}

private struct TaskFAQSectionView: View {
    let title: String
    let items: [FAQItem]

    var body: some View {
        TaskSectionCard(title: title, icon: "questionmark.circle") {
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    DisclosureGroup(item.question) {
                        Text(item.answer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
    }
}

private struct TaskUnsupportedSectionView: View {
    let section: UnsupportedSectionData

    var body: some View {
        TaskSectionCard(title: section.title ?? "More information", icon: "info.circle") {
            VStack(alignment: .leading, spacing: Theme.spaceS) {
                Text("Section type: \(section.type)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let payload = section.payload {
                    TaskJSONValueView(value: payload)
                } else {
                    Text("No additional content available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TaskJSONValueView: View {
    let value: JSONValue

    var body: some View {
        switch value {
        case .object(let dictionary):
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(dictionary.keys.sorted(), id: \.self) { key in
                    if let payload = dictionary[key] {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.humanReadableJSONKey)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TaskJSONValueView(value: payload)
                                .padding(.leading, Theme.spaceXS)
                        }
                    }
                }
            }
        case .array(let array):
            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                ForEach(Array(array.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        TaskJSONValueView(value: item)
                    }
                }
            }
        case .string(let stringValue):
            Text(stringValue)
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .number(let numberValue):
            Text(numberValue.formatted())
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .bool(let boolValue):
            Text(boolValue ? "Yes" : "No")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .null:
            Text("None")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

private extension String {
    var humanReadableJSONKey: String {
        self
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private struct CheckMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? Theme.accent : Theme.strokeStrong, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isOn ? Theme.accent.opacity(0.12) : Color.clear)
                )

            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct SoftProgressBar: View {
    let progress: Double
    var height: CGFloat = 10
    var useDecorativeEffects: Bool = true

    private var normalizedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.track)

            Capsule()
                .fill(Theme.accent)
                .opacity(normalizedProgress > 0 ? 1 : 0)
                .scaleEffect(x: normalizedProgress, y: 1, anchor: .leading)
                .shadow(
                    color: useDecorativeEffects ? Theme.accent.opacity(0.2) : .clear,
                    radius: 6,
                    x: 0,
                    y: 2
                )
        }
        .frame(height: height)
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var categories: [ChecklistCategory]
    let onTaskAdded: () -> Void

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var selectedCategoryID: String

    init(
        categories: Binding<[ChecklistCategory]>,
        onTaskAdded: @escaping () -> Void = {}
    ) {
        self._categories = categories
        self.onTaskAdded = onTaskAdded
        self._selectedCategoryID = State(
            initialValue: categories.wrappedValue.first?.id ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)
                    TextField("Short note (optional)", text: $detail)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(categories) { category in
                            Text(category.title).tag(category.id)
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .glassSheetPresentation(conservative: PerformanceProfile.prefersConservativeVisuals)
    }

    private func addTask() {
        guard let index = categories.firstIndex(where: { $0.id == selectedCategoryID }) else {
            dismiss()
            return
        }

        let newTask = ChecklistTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            isComplete: false,
            isCustom: true
        )

        categories[index].tasks.append(newTask)
        onTaskAdded()
        dismiss()
    }
}

private struct ProfileSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let store: StudentProfileStore

    @State private var fullName: String
    @State private var googleEmailInput: String
    @State private var selectedUniversity: String
    @State private var customUniversity: String
    @State private var courseName: String
    @State private var city: String
    @State private var studyLevel: StudyLevel
    @State private var arrivalDate: Date
    @State private var showGoogleInfo = false
    @State private var showGoogleSignInError = false
    @State private var googleSignInErrorMessage = ""
    @State private var isGoogleSignInInFlight = false
    @State private var showSwitchProviderAlert = false
    @State private var showSignOutAlert = false
    @State private var pendingProviderSwitch: StudentAuthProvider = .none

    init(store: StudentProfileStore) {
        self.store = store
        self._fullName = State(initialValue: store.fullName)
        self._googleEmailInput = State(initialValue: store.email)
        self._courseName = State(initialValue: store.courseName)
        self._city = State(initialValue: store.city)
        self._studyLevel = State(initialValue: store.studyLevel)
        self._arrivalDate = State(initialValue: store.arrivalDate)

        if UniversityCatalog.popularUK.contains(store.selectedUniversity) {
            self._selectedUniversity = State(initialValue: store.selectedUniversity)
            self._customUniversity = State(initialValue: "")
        } else if !store.selectedUniversity.isEmpty {
            self._selectedUniversity = State(initialValue: "Other")
            self._customUniversity = State(initialValue: store.selectedUniversity)
        } else {
            self._selectedUniversity = State(initialValue: UniversityCatalog.popularUK.first ?? "Other")
            self._customUniversity = State(initialValue: "")
        }
    }

    private var resolvedUniversity: String {
        if selectedUniversity == "Other" {
            return customUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedUniversity
    }

    private var normalizedName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedGoogleEmail: String {
        googleEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var requiresGoogleEmail: Bool {
        store.authProvider == .google
    }

    private var isGoogleEmailValid: Bool {
        let candidate = normalizedGoogleEmail
        guard !candidate.isEmpty else { return false }
        let parts = candidate.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        return parts[1].contains(".")
    }

    private var canSave: Bool {
        guard !normalizedName.isEmpty && !resolvedUniversity.isEmpty else { return false }
        if requiresGoogleEmail {
            return isGoogleEmailValid
        }
        return true
    }

    private var googleStatusLabel: String {
        guard store.authProvider == .google else { return "Email mode" }
        return store.googleUserID == nil ? "Email mode" : "Connected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Login") {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(
                        colorScheme == .dark ? .white : .black
                    )
                    .frame(height: 44)

                    if store.authProvider == .apple {
                        Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await handleGoogleTap() }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text(isGoogleSignInInFlight ? "Connecting Google..." : "Continue with Google")
                            Spacer()
                            Text(googleStatusLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isGoogleSignInInFlight)

                    if store.authProvider == .google || !googleEmailInput.isEmpty {
                        TextField("Google email", text: $googleEmailInput)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if !normalizedGoogleEmail.isEmpty && !isGoogleEmailValid {
                            Text("Enter a valid email address")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if store.authProvider != .none {
                        Button("Sign out", role: .destructive) {
                            showSignOutAlert = true
                        }
                    }

                    Text("Current login: \(store.authProvider.label)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Student Details") {
                    TextField("Full name", text: $fullName)

                    Picker("University", selection: $selectedUniversity) {
                        ForEach(UniversityCatalog.popularUK, id: \.self) { university in
                            Text(university).tag(university)
                        }
                        Text("Other").tag("Other")
                    }

                    if selectedUniversity == "Other" {
                        TextField("Enter university name", text: $customUniversity)
                    }

                    TextField("Course", text: $courseName)
                    TextField("City", text: $city)

                    Picker("Study level", selection: $studyLevel) {
                        ForEach(StudyLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }

                    DatePicker("Arrival date", selection: $arrivalDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Student Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(!canSave)
                }
            }
            .alert("Google Sign-In Setup", isPresented: $showGoogleInfo) {
                Button("Use Email Mode") {
                    store.setGoogleMode()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Google Sign-In SDK is not linked or configured. Add GoogleService-Info.plist and GoogleSignIn package, then this button will open Google account login.")
            }
            .alert("Google Sign-In Failed", isPresented: $showGoogleSignInError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(googleSignInErrorMessage)
            }
            .alert("Switch Login Provider?", isPresented: $showSwitchProviderAlert) {
                Button("Switch") {
                    if pendingProviderSwitch == .google {
                        Task { await beginGoogleSignIn() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Switching providers signs out the current account for this device. Your profile data stays saved.")
            }
            .alert("Sign out?", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    GoogleSignInBridge.signOut()
                    store.clearAuthentication()
                    googleEmailInput = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign in again anytime.")
            }
        }
        .glassSheetPresentation(conservative: PerformanceProfile.prefersConservativeVisuals)
    }

    private func handleGoogleTap() async {
        if store.authProvider == .apple {
            pendingProviderSwitch = .google
            showSwitchProviderAlert = true
            return
        }
        await beginGoogleSignIn()
    }

    @MainActor
    private func beginGoogleSignIn() async {
        if !GoogleSignInBridge.isSDKLinked {
            showGoogleInfo = true
            return
        }

        isGoogleSignInInFlight = true
        defer { isGoogleSignInInFlight = false }

        do {
            let identity = try await GoogleSignInBridge.signIn(
                presenting: PresentationAnchor.topViewController()
            )
            store.applyGoogleIdentity(identity)
            googleEmailInput = identity.email

            if normalizedName.isEmpty, let fullName = identity.fullName, !fullName.isEmpty {
                self.fullName = fullName
            }
        } catch GoogleSignInBridgeError.cancelled {
            return
        } catch let knownError as GoogleSignInBridgeError {
            googleSignInErrorMessage = knownError.errorDescription ?? "Google Sign-In failed."
            showGoogleSignInError = true
        } catch {
            googleSignInErrorMessage = error.localizedDescription
            showGoogleSignInError = true
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            store.applyAppleCredential(credential)

            if normalizedName.isEmpty, !store.fullName.isEmpty {
                fullName = store.fullName
            }
        case .failure:
            break
        }
    }

    private func saveProfile() {
        if store.authProvider == .google || (store.authProvider == .none && !normalizedGoogleEmail.isEmpty) {
            store.setGoogleIdentity(email: normalizedGoogleEmail)
        }

        store.updateProfile(
            fullName: normalizedName,
            selectedUniversity: resolvedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate
        )

        dismiss()
    }
}

private struct AdPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: AdPreferencesStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Ad Experience") {
                    Text("Ads are delayed by warm-up and interaction rules to avoid disruption.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "Allow personalized ads",
                        isOn: Binding(
                            get: { preferences.wantsPersonalizedAds },
                            set: { newValue in
                                Task { @MainActor in
                                    await preferences.setPersonalizedAdsRequested(newValue)
                                    AdRuntime.updateConsentConfiguration()
                                }
                            }
                        )
                    )

                    Text("Tracking status: \(preferences.trackingStatusDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Safety Filters") {
                    Text("Blocked categories")
                        .font(.subheadline.weight(.semibold))
                    Text(AdContentRules.blockedCategorySummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    if let url = URL(string: AdLegal.privacyPolicyURL) {
                        Link("Open privacy policy", destination: url)
                    }
                }
            }
            .navigationTitle("Ad & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .glassSheetPresentation(conservative: PerformanceProfile.prefersConservativeVisuals)
    }
}

private struct CategoryPalette: Hashable {
    let fill: Color

    var gradient: Color {
        fill
    }

    var shadowColor: Color {
        fill
    }
}

private enum Theme {
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

    // Primary Navy Scale
    static let navy50 = color(0xF0F4F8)
    static let navy100 = color(0xD9E2EC)
    static let navy200 = color(0xBCCCDC)
    static let navy300 = color(0x9FB3C8)
    static let navy400 = color(0x829AB1)
    static let navy500 = color(0x627D98)
    static let navy600 = color(0x486581)
    static let navy700 = color(0x334E68)
    static let navy800 = color(0x243B53)
    static let navy900 = color(0x1E3A5F)

    // Terracotta Scale
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

    // Sage Scale
    static let sage50 = color(0xF2F7F5)
    static let sage100 = color(0xE0EBE6)
    static let sage200 = color(0xC1D7CE)
    static let sage300 = color(0xA2C3B5)
    static let sage400 = color(0x92BBAA)
    static let sage500 = color(0x81B29A)
    static let sage600 = color(0x6FA188)
    static let sage700 = color(0x5C8B75)
    static let sage800 = color(0x4A7161)
    static let sage900 = color(0x38564B)

    // Warm Orange Scale
    static let warmOrange50 = color(0xFEF8F3)
    static let warmOrange100 = color(0xFDEEE0)
    static let warmOrange200 = color(0xFBDDC1)
    static let warmOrange300 = color(0xF8CCA2)
    static let warmOrange400 = color(0xF6B882)
    static let warmOrange500 = color(0xF4A261)
    static let warmOrange600 = color(0xF08D42)
    static let warmOrange700 = color(0xE67424)
    static let warmOrange800 = color(0xC7621E)
    static let warmOrange900 = color(0xA14F18)

    // Neutral Scale
    static let cream50 = color(0xFDFCFA)
    static let cream100 = color(0xF9F7F4)
    static let cream200 = color(0xF4F1DE)
    static let cream300 = color(0xEBE8D5)
    static let cream400 = color(0xE2DFCC)
    static let cream500 = color(0xD9D6C3)

    static let gray50 = color(0xF8F9FA)
    static let gray100 = color(0xF1F3F5)
    static let gray200 = color(0xE9ECEF)
    static let gray300 = color(0xDEE2E6)
    static let gray400 = color(0xCED4DA)
    static let gray500 = color(0xADB5BD)
    static let gray600 = color(0x868E96)
    static let gray700 = color(0x495057)
    static let gray800 = color(0x343A40)
    static let gray900 = color(0x212529)

    // Semantic
    static let successLight = color(0xD4E7DD)
    static let successMain = color(0x81B29A)
    static let successDark = color(0x5C8B75)
    static let warningLight = color(0xFDEEE0)
    static let warningMain = color(0xF4A261)
    static let warningDark = color(0xE67424)
    static let errorLight = color(0xF8D7DA)
    static let errorMain = color(0xD94F4F)
    static let errorDark = color(0xB93A3A)
    static let infoLight = color(0xD9E2EC)
    static let infoMain = color(0x627D98)
    static let infoDark = color(0x334E68)

    static let accent = terracotta500
    static let accentSoft = terracotta600
    static let inverseText = color(0xFFFFFF)
    static let linkText = terracotta500

    static let primaryText = color(0x0D1B2A)
    static let secondaryText = gray700
    static let tertiaryText = color(0x6C757D)

    static let brandGradient: Color = terracotta500

    static let track = gray200
    static let card = color(0xFFFFFF)
    static let stroke = gray200
    static let strokeStrong = gray300

    static let shadowSoft = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.08)
    static let shadowElevated = Color.black.opacity(0.12)
    static let shadowCritical = navy900.opacity(0.15)

    static let navBarBackground = color(0xFFFFFF)
    static let navActive = navy900
    static let navActiveBackground = navy50

    static let primaryButtonBackground = terracotta500
    static let primaryButtonPressed = terracotta700

    static func palette(for categoryID: String) -> CategoryPalette {
        switch canonicalCategoryID(categoryID) {
        case "before_arrival", "getting_settled":
            return CategoryPalette(fill: navy900)
        case "health_admin", "admin_legal":
            return CategoryPalette(fill: sage500)
        case "money_banking", "daily_living":
            return CategoryPalette(fill: terracotta500)
        case "travel_discounts":
            return CategoryPalette(fill: warmOrange500)
        default:
            return CategoryPalette(fill: navy900)
        }
    }

    static func palette(for category: ChecklistCategory) -> CategoryPalette {
        if let customHex = category.accentColorHex, let custom = color(fromHexString: customHex) {
            return CategoryPalette(fill: custom)
        }
        if let known = knownPalette(for: category.id) {
            return known
        }
        return CategoryPalette(fill: fallbackCategoryBackground(for: category))
    }

    static func urgencyColor(_ urgency: CategoryUrgencyBand) -> Color {
        switch urgency {
        case .immediate:
            return color(0xD94F4F)
        case .week1:
            return warmOrange500
        case .week2:
            return color(0x627D98)
        case .anytime:
            return terracotta500
        case .completed:
            return sage500
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

    static func categoryBackground(for category: ChecklistCategory) -> Color {
        return palette(for: category).fill
    }

    static func categoryText(for category: ChecklistCategory) -> Color {
        categoryUsesDarkForeground(for: category) ? navy900 : inverseText
    }

    static func categoryBadgeBackground(for category: ChecklistCategory) -> Color {
        switch canonicalCategoryID(category.id) {
        case "before_arrival", "getting_settled":
            return terracotta500
        case "health_admin", "admin_legal":
            return cream200
        case "money_banking", "daily_living":
            return navy900
        case "travel_discounts":
            return color(0xFFFFFF)
        default:
            if category.visualPriority == .critical {
                return terracotta500
            }
            if category.visualPriority == .low || categoryUsesDarkForeground(for: category) {
                return color(0xFFFFFF)
            }
            return cream200
        }
    }

    static func categoryBadgeText(for category: ChecklistCategory) -> Color {
        switch canonicalCategoryID(category.id) {
        case "before_arrival", "money_banking", "getting_settled", "daily_living":
            return inverseText
        default:
            return navy900
        }
    }

    static func categoryUsesDarkForeground(for category: ChecklistCategory) -> Bool {
        if let customHex = category.accentColorHex, let colorComponents = rgb(fromHexString: customHex) {
            // Keep category cards white-text by default. Only switch to dark text for unusually bright custom colors.
            return colorComponents.relativeLuminance > 0.85
        }

        return false
    }

    static func accentColor(for category: ChecklistCategory) -> Color {
        categoryBackground(for: category)
    }

    static func background(for scheme: ColorScheme, conservative: Bool) -> some View {
        _ = scheme
        _ = conservative
        return AnyView(cream200)
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

    private static func knownPalette(for categoryID: String) -> CategoryPalette? {
        switch canonicalCategoryID(categoryID) {
        case "before_arrival", "getting_settled":
            return CategoryPalette(fill: navy900)
        case "health_admin", "admin_legal":
            return CategoryPalette(fill: sage500)
        case "money_banking", "daily_living":
            return CategoryPalette(fill: terracotta500)
        case "travel_discounts":
            return CategoryPalette(fill: warmOrange500)
        default:
            return nil
        }
    }

    private static func canonicalCategoryID(_ rawID: String) -> String {
        rawID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func fallbackCategoryBackground(for category: ChecklistCategory) -> Color {
        switch category.visualPriority {
        case .critical:
            return navy900
        case .high:
            return category.urgencyBand == .week1 ? sage500 : terracotta500
        case .medium:
            return terracotta500
        case .low:
            if category.urgencyBand == .completed {
                return sage600
            }
            return warmOrange500
        }
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

private struct CardChromeModifier: ViewModifier {
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

private struct GlassSheetPresentationModifier: ViewModifier {
    let conservative: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let mode = GlassRenderingPolicy.resolveMode(
            conservative: conservative,
            reduceTransparency: reduceTransparency
        )

        if mode == .solid {
            content
                .presentationBackground(Theme.card)
        } else {
            content
                .presentationBackground(.regularMaterial)
        }
    }
}

private extension View {
    func cardChrome(elevated: Bool) -> some View {
        modifier(CardChromeModifier(elevated: elevated))
    }

    func glassSheetPresentation(conservative: Bool) -> some View {
        modifier(GlassSheetPresentationModifier(conservative: conservative))
    }
}

private enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .soft)

    static func softImpactIfAllowed() {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
    }
}

private enum PerformanceProfile {
    private static let lowMemoryThresholdBytes: UInt64 = 3_500_000_000

    static var prefersConservativeVisuals: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || isLowMemoryClass
    }

    private static var isLowMemoryClass: Bool {
        ProcessInfo.processInfo.physicalMemory <= lowMemoryThresholdBytes
    }
}

private enum LaunchMetrics {
    private static let launchUptime = ProcessInfo.processInfo.systemUptime
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "startup"
    )

    static func mark(event: String) {
        #if DEBUG
        let elapsed = ProcessInfo.processInfo.systemUptime - launchUptime
        logger.debug("\(event, privacy: .public) +\(elapsed, format: .fixed(precision: 3))s")
        #endif
    }
}

private enum AdTopic: String, CaseIterable {
    case education
    case finance
    case transport
    case housing
    case groceries
    case career
    case gambling
    case betting
    case adult
    case dating
    case alcohol
    case tobacco
}

private enum AdContentRules {
    static let blockedTopics: Set<AdTopic> = [
        .gambling,
        .betting,
        .adult,
        .dating,
        .alcohol,
        .tobacco
    ]

    static let defaultSafeTopics: Set<AdTopic> = [
        .education,
        .finance,
        .transport,
        .housing,
        .groceries,
        .career
    ]

    static let blockedCategorySummary = "Gambling, betting, adult, dating, alcohol, and tobacco."

    static func allows(topics: Set<AdTopic>) -> Bool {
        !topics.isEmpty && topics.isDisjoint(with: blockedTopics)
    }
}

private enum AdEvent: String {
    case appBecameActive = "app_became_active"
    case taskToggled = "task_toggled"
    case taskDetailOpened = "task_detail_opened"
    case personalTaskAdded = "personal_task_added"
    case resourceOpened = "resource_opened"

    var countsAsInteraction: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return true
        case .appBecameActive:
            return false
        }
    }

    var canTriggerEvaluation: Bool {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return true
        case .appBecameActive:
            return false
        }
    }

    var topics: Set<AdTopic> {
        switch self {
        case .taskToggled, .taskDetailOpened, .personalTaskAdded, .resourceOpened:
            return AdContentRules.defaultSafeTopics
        case .appBecameActive:
            return []
        }
    }
}

private enum AdPlacement: String {
    case inlineContextual = "inline_contextual"
}

private struct AdOpportunity {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let issuedAt: Date
}

private struct AdPolicyConfig {
    let warmupSeconds: TimeInterval = 180
    let minimumInteractionsBeforeFirstAd: Int = 4
    let minimumSecondsBetweenAds: TimeInterval = 240
    let maxAdsPerSession: Int = 8
    let maxAdsPerRollingHour: Int = 6
}

private enum AdHoldReason {
    case nonTriggerEvent
    case warmupNotFinished
    case notEnoughEngagement
    case cooldownActive
    case sessionCapReached
    case hourlyCapReached
    case lowPowerMode
}

private enum AdDecision {
    case allow
    case hold(AdHoldReason)
}

private enum TrackingAuthorizationState: Int {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
    case unavailable = 4

    var description: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .unavailable:
            return "Unavailable"
        }
    }
}

@Observable
private final class AdPreferencesStore {
    static let shared = AdPreferencesStore()

    private let defaults = UserDefaults.standard
    private let wantsPersonalizedAdsKey = "ads.wantsPersonalizedAds"
    private let trackingStateKey = "ads.trackingAuthorizationState"
    private let hasAcceptedDisclosureKey = "ads.hasAcceptedDisclosure"

    private var hasBootstrapped = false

    var wantsPersonalizedAds: Bool = false
    var trackingAuthorizationState: TrackingAuthorizationState = .notDetermined
    var hasAcceptedDisclosure: Bool = false

    var trackingStatusDescription: String {
        trackingAuthorizationState.description
    }

    var effectivePersonalizedAdsEnabled: Bool {
        wantsPersonalizedAds && trackingAuthorizationState == .authorized
    }

    private init() {
        wantsPersonalizedAds = defaults.bool(forKey: wantsPersonalizedAdsKey)
        hasAcceptedDisclosure = defaults.bool(forKey: hasAcceptedDisclosureKey)
        let rawState = defaults.integer(forKey: trackingStateKey)
        trackingAuthorizationState = TrackingAuthorizationState(rawValue: rawState) ?? .notDetermined
    }

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        refreshTrackingStatusFromSystem()
    }

    @MainActor
    func updateDisclosureAccepted() {
        hasAcceptedDisclosure = true
        persist()
    }

    @MainActor
    func setPersonalizedAdsRequested(_ enabled: Bool) async {
        updateDisclosureAccepted()
        wantsPersonalizedAds = enabled

        if enabled {
            let newStatus = await requestTrackingAuthorizationIfPossible()
            trackingAuthorizationState = newStatus
            if newStatus != .authorized {
                wantsPersonalizedAds = false
            }
        } else {
            refreshTrackingStatusFromSystem()
        }

        persist()
    }

    @MainActor
    func refreshTrackingStatusFromSystem() {
        trackingAuthorizationState = Self.currentTrackingAuthorizationState()
        persist()
    }

    @MainActor
    private func persist() {
        defaults.set(wantsPersonalizedAds, forKey: wantsPersonalizedAdsKey)
        defaults.set(hasAcceptedDisclosure, forKey: hasAcceptedDisclosureKey)
        defaults.set(trackingAuthorizationState.rawValue, forKey: trackingStateKey)
    }

    @MainActor
    private func requestTrackingAuthorizationIfPossible() async -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") != nil else {
                return .denied
            }

            let result = await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            return Self.mapTrackingStatus(result)
        }
        #endif

        return .unavailable
    }

    private static func currentTrackingAuthorizationState() -> TrackingAuthorizationState {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            return mapTrackingStatus(ATTrackingManager.trackingAuthorizationStatus)
        }
        #endif

        return .unavailable
    }

    #if canImport(AppTrackingTransparency)
    @available(iOS 14, *)
    private static func mapTrackingStatus(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> TrackingAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

@Observable
private final class AdCoordinator {
    private(set) var sessionStartedAt: Date?
    private(set) var interactionCount = 0
    private(set) var opportunitiesIssued = 0
    private(set) var lastOpportunityAt: Date?

    private var recentOpportunityDates: [Date] = []

    private let config = AdPolicyConfig()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-policy"
    )

    @MainActor
    func startSessionIfNeeded(now: Date = .now) {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = now
        LaunchMetrics.mark(event: "ad_session_started")
    }

    @MainActor
    func register(event: AdEvent, now: Date = .now) -> AdOpportunity? {
        startSessionIfNeeded(now: now)

        if event.countsAsInteraction {
            interactionCount += 1
        }

        switch evaluate(event: event, now: now) {
        case .allow:
            pruneHourlyWindow(reference: now)
            opportunitiesIssued += 1
            lastOpportunityAt = now
            recentOpportunityDates.append(now)

            #if DEBUG
            logger.debug(
                "ad_allowed event=\(event.rawValue, privacy: .public) issued=\(self.opportunitiesIssued)"
            )
            #endif

            return AdOpportunity(
                placement: .inlineContextual,
                sourceEvent: event,
                topics: event.topics,
                issuedAt: now
            )
        case .hold:
            return nil
        }
    }

    @MainActor
    private func evaluate(event: AdEvent, now: Date) -> AdDecision {
        guard event.canTriggerEvaluation else { return .hold(.nonTriggerEvent) }
        guard let sessionStartedAt else { return .hold(.warmupNotFinished) }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .hold(.lowPowerMode)
        }

        if now.timeIntervalSince(sessionStartedAt) < config.warmupSeconds {
            return .hold(.warmupNotFinished)
        }

        if interactionCount < config.minimumInteractionsBeforeFirstAd {
            return .hold(.notEnoughEngagement)
        }

        if opportunitiesIssued >= config.maxAdsPerSession {
            return .hold(.sessionCapReached)
        }

        if let lastOpportunityAt,
           now.timeIntervalSince(lastOpportunityAt) < config.minimumSecondsBetweenAds {
            return .hold(.cooldownActive)
        }

        pruneHourlyWindow(reference: now)
        if recentOpportunityDates.count >= config.maxAdsPerRollingHour {
            return .hold(.hourlyCapReached)
        }

        return .allow
    }

    @MainActor
    private func pruneHourlyWindow(reference: Date) {
        let cutoff = reference.addingTimeInterval(-3600)
        recentOpportunityDates.removeAll { $0 < cutoff }
    }
}

private struct AdConsentSnapshot {
    let effectivePersonalizedAdsEnabled: Bool
}

private struct AdRequestContext {
    let placement: AdPlacement
    let sourceEvent: AdEvent
    let topics: Set<AdTopic>
    let nonPersonalized: Bool
}

private protocol AdNetworkClient {
    func configureIfNeeded(consent: AdConsentSnapshot)
    func updateConsent(_ consent: AdConsentSnapshot)
    func requestAd(context: AdRequestContext)
}

private final class NoOpAdNetworkClient: AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-noop"
    )

    func configureIfNeeded(consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_configured personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        #if DEBUG
        logger.debug("ad_client_noop_consent_updated personalized=\(consent.effectivePersonalizedAdsEnabled)")
        #endif
    }

    func requestAd(context: AdRequestContext) {
        #if DEBUG
        logger.debug(
            "ad_client_noop_request placement=\(context.placement.rawValue, privacy: .public) event=\(context.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }
}

#if canImport(GoogleMobileAds)
import GoogleMobileAds

private final class GoogleMobileAdsClient: NSObject, AdNetworkClient {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime-gma"
    )

    private var isConfigured = false
    private var latestConsent = AdConsentSnapshot(effectivePersonalizedAdsEnabled: false)
    private var cachedInterstitial: GADInterstitialAd?

    private var adUnitID: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ADMOB_INTERSTITIAL_UNIT_ID") as? String
        return configured ?? "ca-app-pub-3940256099942544/4411468910"
    }

    func configureIfNeeded(consent: AdConsentSnapshot) {
        latestConsent = consent
        guard !isConfigured else { return }
        isConfigured = true

        GADMobileAds.sharedInstance().start(completionHandler: nil)

        #if DEBUG
        logger.debug("gma_started")
        #endif
    }

    func updateConsent(_ consent: AdConsentSnapshot) {
        latestConsent = consent
    }

    func requestAd(context: AdRequestContext) {
        guard isConfigured else {
            configureIfNeeded(consent: latestConsent)
            return
        }

        let request = GADRequest()
        request.keywords = context.topics.map(\.rawValue)

        if context.nonPersonalized {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                #if DEBUG
                self.logger.debug("gma_load_failed \(error.localizedDescription, privacy: .public)")
                #endif
                return
            }

            self.cachedInterstitial = ad
            #if DEBUG
            self.logger.debug("gma_interstitial_loaded")
            #endif
        }
    }
}
#endif

private enum AdLegal {
    static let privacyPolicyURL = "https://example.com/privacy"
}

private enum AdRuntime {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "ad-runtime"
    )

    private static let preferences = AdPreferencesStore.shared
    private static var bootstrapped = false

    private static let adClient: any AdNetworkClient = {
        #if canImport(GoogleMobileAds)
        return GoogleMobileAdsClient()
        #else
        return NoOpAdNetworkClient()
        #endif
    }()

    @MainActor
    static func bootstrapIfNeeded() {
        guard !bootstrapped else { return }
        bootstrapped = true

        preferences.bootstrapIfNeeded()
        adClient.configureIfNeeded(consent: consentSnapshot())
    }

    @MainActor
    static func updateConsentConfiguration() {
        preferences.refreshTrackingStatusFromSystem()
        adClient.updateConsent(consentSnapshot())
    }

    @MainActor
    static func requestAd(for opportunity: AdOpportunity) {
        bootstrapIfNeeded()

        guard AdContentRules.allows(topics: opportunity.topics) else {
            #if DEBUG
            logger.debug("ad_request_blocked_by_category_filter")
            #endif
            return
        }

        let context = AdRequestContext(
            placement: opportunity.placement,
            sourceEvent: opportunity.sourceEvent,
            topics: opportunity.topics,
            nonPersonalized: !preferences.effectivePersonalizedAdsEnabled
        )

        adClient.requestAd(context: context)

        #if DEBUG
        logger.debug(
            "ad_request placement=\(opportunity.placement.rawValue, privacy: .public) source=\(opportunity.sourceEvent.rawValue, privacy: .public)"
        )
        #endif
    }

    @MainActor
    private static func consentSnapshot() -> AdConsentSnapshot {
        AdConsentSnapshot(
            effectivePersonalizedAdsEnabled: preferences.effectivePersonalizedAdsEnabled
        )
    }
}

private enum StudentAuthProvider: String, Codable, Hashable {
    case none
    case apple
    case google

    var label: String {
        switch self {
        case .none:
            return "Not signed in"
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }
}

private enum StudyLevel: String, CaseIterable, Codable, Hashable {
    case foundation
    case undergraduate
    case postgraduate
    case phd
    case other

    var label: String {
        switch self {
        case .foundation:
            return "Foundation"
        case .undergraduate:
            return "Undergraduate"
        case .postgraduate:
            return "Postgraduate"
        case .phd:
            return "PhD"
        case .other:
            return "Other"
        }
    }
}

private struct StudentProfileSnapshot: Codable {
    var authProvider: StudentAuthProvider
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String
    var email: String
    var selectedUniversity: String
    var courseName: String
    var city: String
    var studyLevel: StudyLevel
    var arrivalDate: Date
    var hasCompletedSetup: Bool
}

@Observable
private final class StudentProfileStore {
    static let shared = StudentProfileStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "student.profile.v1"
    private var hasBootstrapped = false

    var authProvider: StudentAuthProvider = .none
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String = ""
    var email: String = ""
    var selectedUniversity: String = ""
    var courseName: String = ""
    var city: String = ""
    var studyLevel: StudyLevel = .undergraduate
    var arrivalDate: Date = .now
    var hasCompletedSetup: Bool = false

    var preferredFirstName: String? {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init)
    }

    private init() {}

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadFromDefaults()
    }

    @MainActor
    func setGoogleMode() {
        authProvider = .google
        appleUserID = nil
        googleUserID = nil
        persist()
    }

    @MainActor
    func setGoogleIdentity(email: String, userID: String? = nil) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return }
        authProvider = .google
        appleUserID = nil
        googleUserID = userID
        self.email = normalizedEmail.lowercased()
        persist()
    }

    @MainActor
    func applyGoogleIdentity(_ identity: GoogleSignInIdentity) {
        authProvider = .google
        appleUserID = nil
        googleUserID = identity.userID
        email = identity.email.lowercased()
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = identity.fullName,
           !name.isEmpty {
            fullName = name
        }
        persist()
    }

    @MainActor
    func clearAuthentication() {
        authProvider = .none
        appleUserID = nil
        googleUserID = nil
        email = ""
        persist()
    }

    @MainActor
    func applyAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        authProvider = .apple
        appleUserID = credential.user
        googleUserID = nil

        if let email = credential.email, !email.isEmpty {
            self.email = email.lowercased()
        }

        if let givenName = credential.fullName?.givenName, !givenName.isEmpty {
            let familyName = credential.fullName?.familyName ?? ""
            let combined = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                fullName = combined
            }
        }

        persist()
    }

    @MainActor
    func updateProfile(
        fullName: String,
        selectedUniversity: String,
        courseName: String,
        city: String,
        studyLevel: StudyLevel,
        arrivalDate: Date
    ) {
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedUniversity = selectedUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        self.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        self.studyLevel = studyLevel
        self.arrivalDate = arrivalDate
        hasCompletedSetup = !self.fullName.isEmpty && !self.selectedUniversity.isEmpty
        persist()
    }

    @MainActor
    private func loadFromDefaults() {
        guard
            let data = defaults.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(StudentProfileSnapshot.self, from: data)
        else {
            return
        }

        authProvider = snapshot.authProvider
        appleUserID = snapshot.appleUserID
        googleUserID = snapshot.googleUserID
        fullName = snapshot.fullName
        email = snapshot.email
        selectedUniversity = snapshot.selectedUniversity
        courseName = snapshot.courseName
        city = snapshot.city
        studyLevel = snapshot.studyLevel
        arrivalDate = snapshot.arrivalDate
        hasCompletedSetup = snapshot.hasCompletedSetup
    }

    @MainActor
    private func persist() {
        let snapshot = StudentProfileSnapshot(
            authProvider: authProvider,
            appleUserID: appleUserID,
            googleUserID: googleUserID,
            fullName: fullName,
            email: email,
            selectedUniversity: selectedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate,
            hasCompletedSetup: hasCompletedSetup
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private enum UniversityCatalog {
    static let popularUK: [String] = [
        "University of Oxford",
        "University of Cambridge",
        "Imperial College London",
        "UCL",
        "King's College London",
        "University of Edinburgh",
        "University of Manchester",
        "University of Birmingham",
        "University of Leeds",
        "University of Glasgow",
        "University of Bristol",
        "University of Nottingham",
        "University of Sheffield",
        "University of Warwick",
        "Queen Mary University of London",
        "University of Southampton",
        "Newcastle University",
        "University of Liverpool",
        "University of York",
        "University of Exeter"
    ]
}

@Observable
private final class ContentStore {
    var categories: [ChecklistCategory] = []
    private let defaults = UserDefaults.standard
    private let progressKey = "content.store.progress.v1"

    @MainActor
    func loadFromBundle() {
        LaunchMetrics.mark(event: "bundle_content_load_begin")

        for candidate in ["categories", "content"] {
            if let payload = ContentPayload.loadFromBundle(named: candidate), !payload.categories.isEmpty {
                categories = normalizedCategories(sanitize(payload.categories))
                applyPersistedProgressIfAvailable()
                LaunchMetrics.mark(event: "bundle_content_load_success_\(candidate)")
                return
            }
        }

        categories = normalizedCategories(sanitize(SampleData.categories))
        applyPersistedProgressIfAvailable()
        LaunchMetrics.mark(event: "bundle_content_load_fallback_sample")
    }

    @MainActor
    func persistProgress() {
        guard !categories.isEmpty else { return }

        let completedTaskIDs = categories
            .flatMap(\.tasks)
            .filter(\.isComplete)
            .map(\.id)

        var customTasksByCategory: [String: [ChecklistTask]] = [:]
        for category in categories {
            let customTasks = category.tasks.filter(\.isCustom)
            if !customTasks.isEmpty {
                customTasksByCategory[category.id] = customTasks
            }
        }

        let snapshot = ContentProgressSnapshot(
            completedTaskIDs: completedTaskIDs,
            customTasksByCategory: customTasksByCategory
        )

        guard let encoded = try? JSONEncoder().encode(snapshot) else {
            LaunchMetrics.mark(event: "content_progress_encode_failed")
            return
        }

        defaults.set(encoded, forKey: progressKey)
    }

    @MainActor
    private func applyPersistedProgressIfAvailable() {
        guard
            let data = defaults.data(forKey: progressKey),
            let snapshot = try? JSONDecoder().decode(ContentProgressSnapshot.self, from: data)
        else {
            return
        }

        let completedTaskIDs = Set(snapshot.completedTaskIDs)
        var updatedCategories: [ChecklistCategory] = []

        for var category in categories {
            if let savedCustomTasks = snapshot.customTasksByCategory[category.id], !savedCustomTasks.isEmpty {
                let existingIDs = Set(category.tasks.map(\.id))
                let missingCustomTasks = savedCustomTasks.filter { !existingIDs.contains($0.id) }
                category.tasks.append(contentsOf: missingCustomTasks)
            }

            for index in category.tasks.indices {
                category.tasks[index].isComplete = completedTaskIDs.contains(category.tasks[index].id)
            }

            updatedCategories.append(category)
        }

        categories = normalizedCategories(updatedCategories)
        LaunchMetrics.mark(event: "content_progress_applied")
    }

    private func normalizedCategories(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
        let sortedCategories = input.sorted { left, right in
            let leftOrder = left.order ?? Int.max
            let rightOrder = right.order ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            let leftPriority = left.visualPriority.ranking
            let rightPriority = right.visualPriority.ranking
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }

            let leftUrgency = left.urgencyBand.ranking
            let rightUrgency = right.urgencyBand.ranking
            if leftUrgency != rightUrgency {
                return leftUrgency < rightUrgency
            }

            return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
        }

        return sortedCategories.map { category in
            var updatedCategory = category
            updatedCategory.tasks = category.tasks.sorted { left, right in
                let leftOrder = left.order ?? Int.max
                let rightOrder = right.order ?? Int.max

                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }

                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return updatedCategory
        }
    }

    private func sanitize(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
        var seenCategoryIDs: Set<String> = []
        var output: [ChecklistCategory] = []

        for var category in input {
            let categoryID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryTitle = category.title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !categoryID.isEmpty, !categoryTitle.isEmpty else {
                continue
            }

            guard !seenCategoryIDs.contains(categoryID) else {
                continue
            }

            seenCategoryIDs.insert(categoryID)
            category.title = categoryTitle

            if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                category.icon = "square.grid.2x2"
            }

            var seenTaskIDs: Set<String> = []
            var cleanedTasks: [ChecklistTask] = []

            for task in category.tasks {
                let taskID = task.id.trimmingCharacters(in: .whitespacesAndNewlines)
                let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !taskID.isEmpty, !taskTitle.isEmpty else {
                    continue
                }

                guard !seenTaskIDs.contains(taskID) else {
                    continue
                }

                seenTaskIDs.insert(taskID)
                cleanedTasks.append(task)
            }

            category.tasks = cleanedTasks
            output.append(category)
        }

        return output
    }
}

private struct ContentProgressSnapshot: Codable {
    var completedTaskIDs: [String]
    var customTasksByCategory: [String: [ChecklistTask]]
}

private struct ContentPayload: Codable {
    let categories: [ChecklistCategory]

    private static var cachedPayload: ContentPayload?

    @MainActor
    static func loadFromBundle(named fileName: String) -> ContentPayload? {
        if let cachedPayload {
            LaunchMetrics.mark(event: "bundle_content_cache_hit")
            return cachedPayload
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            LaunchMetrics.mark(event: "bundle_content_missing_file")
            return nil
        }

        let decodeStart = ProcessInfo.processInfo.systemUptime

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            LaunchMetrics.mark(event: "bundle_content_read_failed")
            return nil
        }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ContentPayload.self, from: data) else {
            LaunchMetrics.mark(event: "bundle_content_decode_failed")
            return nil
        }

        let validation = ContentValidator.validate(payload: payload)
        validation.logSummary(fileName: fileName)
        LaunchMetrics.mark(
            event: "bundle_content_validation_w\(validation.warningCount)_e\(validation.errorCount)"
        )

        #if DEBUG
        if validation.hasErrors {
            LaunchMetrics.mark(event: "bundle_content_validation_failed_debug")
            return nil
        }
        #endif

        cachedPayload = payload
        let elapsed = ProcessInfo.processInfo.systemUptime - decodeStart
        LaunchMetrics.mark(event: "bundle_content_decode_success_\(Int(elapsed * 1000))ms")
        return payload
    }
}

private enum ContentIssueSeverity: String {
    case warning
    case error
}

private struct ContentValidationIssue: Hashable {
    let severity: ContentIssueSeverity
    let path: String
    let message: String
}

private struct ContentValidationReport {
    let issues: [ContentValidationIssue]

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var hasErrors: Bool {
        errorCount > 0
    }

    func logSummary(fileName: String) {
        #if DEBUG
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
            category: "content-validation"
        )

        logger.debug(
            "content_validation file=\(fileName, privacy: .public) warnings=\(self.warningCount) errors=\(self.errorCount)"
        )

        for issue in issues.prefix(120) {
            logger.debug(
                "content_validation_issue severity=\(issue.severity.rawValue, privacy: .public) path=\(issue.path, privacy: .public) message=\(issue.message, privacy: .public)"
            )
        }
        #endif
    }
}

private enum ContentValidator {
    private static let allowedSchemes: Set<String> = ["https", "http"]
    private static let trustedOfficialDomainSuffixes: [String] = [
        "gov.uk",
        "ac.uk",
        "nhs.uk",
        "nationalrail.co.uk",
        "ukri.org.uk",
        "ukfinance.org.uk",
        "ukcisa.org.uk",
        "hsbc.co.uk",
        "lloydsbank.com",
        "aldi.co.uk",
        "tesco.com",
        "studentbeans.com",
        "totum.com"
    ]

    static func validate(payload: ContentPayload) -> ContentValidationReport {
        var issues: [ContentValidationIssue] = []

        if payload.categories.isEmpty {
            issues.append(
                ContentValidationIssue(
                    severity: .error,
                    path: "categories",
                    message: "No categories found in payload."
                )
            )
            return ContentValidationReport(issues: issues)
        }

        var seenCategoryIDs: Set<String> = []

        for (categoryIndex, category) in payload.categories.enumerated() {
            let categoryPath = "categories[\(categoryIndex)]"
            validateCategory(
                category,
                path: categoryPath,
                issues: &issues,
                seenCategoryIDs: &seenCategoryIDs
            )
        }

        return ContentValidationReport(issues: issues)
    }

    private static func validateCategory(
        _ category: ChecklistCategory,
        path: String,
        issues: inout [ContentValidationIssue],
        seenCategoryIDs: inout Set<String>
    ) {
        let categoryID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if categoryID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Category id is empty."))
        } else if seenCategoryIDs.contains(categoryID) {
            issues.append(
                issue(.error, path: "\(path).id", message: "Duplicate category id '\(categoryID)'.")
            )
        } else {
            seenCategoryIDs.insert(categoryID)
        }

        if category.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.error, path: "\(path).title", message: "Category title is empty."))
        }

        if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.warning, path: "\(path).icon", message: "Category icon is empty."))
        }

        if category.tasks.isEmpty {
            issues.append(
                issue(.warning, path: "\(path).tasks", message: "Category has no tasks.")
            )
        }

        if let deadline = category.deadline, !deadline.isEmpty {
            if !isValidDate(deadline) {
                issues.append(
                    issue(
                        .warning,
                        path: "\(path).deadline",
                        message: "Deadline '\(deadline)' is not in ISO-8601 date format (yyyy-MM-dd)."
                    )
                )
            }
        }

        var seenTaskIDs: Set<String> = []
        for (taskIndex, task) in category.tasks.enumerated() {
            validateTask(
                task,
                path: "\(path).tasks[\(taskIndex)]",
                issues: &issues,
                seenTaskIDs: &seenTaskIDs
            )
        }
    }

    private static func validateTask(
        _ task: ChecklistTask,
        path: String,
        issues: inout [ContentValidationIssue],
        seenTaskIDs: inout Set<String>
    ) {
        let taskID = task.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if taskID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Task id is empty."))
        } else if seenTaskIDs.contains(taskID) {
            issues.append(issue(.error, path: "\(path).id", message: "Duplicate task id '\(taskID)'."))
        } else {
            seenTaskIDs.insert(taskID)
        }

        if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.error, path: "\(path).title", message: "Task title is empty."))
        }

        if let minutes = task.estimatedMinutes, minutes < 0 {
            issues.append(
                issue(.warning, path: "\(path).estimatedMinutes", message: "Estimated minutes is negative.")
            )
        }

        if let sourceURL = task.sourceURL {
            validateURLString(
                sourceURL,
                path: "\(path).sourceURL",
                issues: &issues,
                expectedTrust: nil
            )
        }

        guard let content = task.content else { return }
        validateTaskContent(content, path: "\(path).content", issues: &issues)
    }

    private static func validateTaskContent(
        _ content: TaskContent,
        path: String,
        issues: inout [ContentValidationIssue]
    ) {
        if content.sections.isEmpty {
            issues.append(issue(.warning, path: "\(path).sections", message: "Task content has no sections."))
        }

        for (sectionIndex, section) in content.sections.enumerated() {
            let sectionPath = "\(path).sections[\(sectionIndex)]"

            switch section {
            case .options(let data), .comparisonTable(let data):
                if data.items.isEmpty {
                    issues.append(
                        issue(
                            .warning,
                            path: "\(sectionPath).items",
                            message: "Options section has no items."
                        )
                    )
                }

                for (itemIndex, item) in data.items.enumerated() {
                    let itemPath = "\(sectionPath).items[\(itemIndex)]"
                    if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(itemPath).name", message: "Option item name is empty."))
                    }

                    if let link = item.link {
                        validateURLString(
                            link.url,
                            path: "\(itemPath).link.url",
                            issues: &issues,
                            expectedTrust: link.source?.resolvedTrustType
                        )
                        validateSource(link.source, path: "\(itemPath).link.source", issues: &issues)
                    }

                    validateSource(item.source, path: "\(itemPath).source", issues: &issues)
                }
            case .references(let data):
                validateReferences(data.items, path: "\(sectionPath).items", issues: &issues)
            case .officialReferences(let data):
                validateReferences(data.items, path: "\(sectionPath).items", issues: &issues, officialExpected: true)
            case .steps(let data):
                for (stepIndex, step) in data.items.enumerated() {
                    let stepPath = "\(sectionPath).items[\(stepIndex)]"
                    if step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(stepPath).title", message: "Step title is empty."))
                    }

                    for (actionIndex, action) in step.actions.enumerated() {
                        let actionPath = "\(stepPath).actions[\(actionIndex)]"
                        if let url = action.url {
                            validateURLString(
                                url,
                                path: "\(actionPath).url",
                                issues: &issues,
                                expectedTrust: action.source?.resolvedTrustType
                            )
                        }
                        validateSource(action.source, path: "\(actionPath).source", issues: &issues)
                    }
                }
            case .apps(let data):
                for (appIndex, app) in data.items.enumerated() {
                    let appPath = "\(sectionPath).items[\(appIndex)]"
                    if app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue(.error, path: "\(appPath).name", message: "App name is empty."))
                    }
                    if let ios = app.downloadLinks?.ios {
                        validateURLString(ios, path: "\(appPath).downloadLinks.ios", issues: &issues, expectedTrust: nil)
                    }
                    if let android = app.downloadLinks?.android {
                        validateURLString(android, path: "\(appPath).downloadLinks.android", issues: &issues, expectedTrust: nil)
                    }
                }
            case .why, .overview, .checklist, .tips, .faqs, .unsupported:
                break
            }
        }
    }

    private static func validateReferences(
        _ references: [ReferenceItem],
        path: String,
        issues: inout [ContentValidationIssue],
        officialExpected: Bool = false
    ) {
        for (index, reference) in references.enumerated() {
            let referencePath = "\(path)[\(index)]"
            if reference.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue(.error, path: "\(referencePath).title", message: "Reference title is empty."))
            }

            validateURLString(
                reference.url,
                path: "\(referencePath).url",
                issues: &issues,
                expectedTrust: officialExpected ? .official : reference.resolvedSourceMetadata?.resolvedTrustType
            )

            validateSource(reference.resolvedSourceMetadata, path: "\(referencePath).source", issues: &issues)
        }
    }

    private static func validateSource(
        _ source: SourceMetadata?,
        path: String,
        issues: inout [ContentValidationIssue]
    ) {
        guard let source else { return }

        if let verified = source.lastVerified, !verified.isEmpty, !isValidDate(verified) {
            issues.append(
                issue(
                    .warning,
                    path: "\(path).lastVerified",
                    message: "lastVerified '\(verified)' is not in ISO-8601 date format (yyyy-MM-dd)."
                )
            )
        }
    }

    private static func validateURLString(
        _ urlString: String,
        path: String,
        issues: inout [ContentValidationIssue],
        expectedTrust: SourceTrustType?
    ) {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased() else {
            issues.append(issue(.error, path: path, message: "Invalid URL '\(urlString)'."))
            return
        }

        guard allowedSchemes.contains(scheme) else {
            issues.append(issue(.error, path: path, message: "URL scheme '\(scheme)' is not allowed."))
            return
        }

        if expectedTrust == .official || expectedTrust == .university {
            guard let host = url.host?.lowercased() else {
                issues.append(
                    issue(
                        .warning,
                        path: path,
                        message: "Official/university URL is missing host."
                    )
                )
                return
            }

            if !isTrustedOfficialDomain(host: host) {
                issues.append(
                    issue(
                        .warning,
                        path: path,
                        message: "Official/university source host '\(host)' is not in the trusted suffix list."
                    )
                )
            }
        }
    }

    private static func isValidDate(_ raw: String) -> Bool {
        if isoDateFormatter.date(from: raw) != nil {
            return true
        }
        return fallbackDateFormatter.date(from: raw) != nil
    }

    private static func isTrustedOfficialDomain(host: String) -> Bool {
        trustedOfficialDomainSuffixes.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    private static func issue(
        _ severity: ContentIssueSeverity,
        path: String,
        message: String
    ) -> ContentValidationIssue {
        ContentValidationIssue(severity: severity, path: path, message: message)
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ChecklistStats {
    let totalTasks: Int
    let completedTasks: Int

    var overallProgress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    init(categories: [ChecklistCategory]) {
        var total = 0
        var completed = 0

        for category in categories {
            total += category.tasks.count
            completed += category.tasks.reduce(0) { partialResult, task in
                partialResult + (task.isComplete ? 1 : 0)
            }
        }

        self.totalTasks = total
        self.completedTasks = completed
    }
}

private struct CategoryStats {
    let totalCount: Int
    let completedCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    init(tasks: [ChecklistTask]) {
        self.totalCount = tasks.count
        self.completedCount = tasks.reduce(0) { partialResult, task in
            partialResult + (task.isComplete ? 1 : 0)
        }
    }
}

private enum TaskTiming: String, Codable, Hashable {
    case monthBeforeArrival = "month_before_arrival"
    case weekBeforeArrival = "week_before_arrival"
    case firstWeek = "first_week"
    case firstMonth = "first_month"
    case ongoing = "ongoing"
    case anytime = "anytime"

    var label: String {
        switch self {
        case .monthBeforeArrival:
            return "About a month before"
        case .weekBeforeArrival:
            return "About a week before"
        case .firstWeek:
            return "First week"
        case .firstMonth:
            return "First month"
        case .ongoing:
            return "Ongoing"
        case .anytime:
            return "Anytime"
        }
    }
}

private enum TaskPriority: String, Codable, Hashable {
    case mustDo = "must_do"
    case shouldDo = "should_do"
    case optional = "optional"

    var label: String {
        switch self {
        case .mustDo:
            return "Must do"
        case .shouldDo:
            return "Should do"
        case .optional:
            return "Optional"
        }
    }
}

private enum TaskUrgency: String, Codable, Hashable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:
            return "High urgency"
        case .medium:
            return "Medium urgency"
        case .low:
            return "Low urgency"
        }
    }
}

private enum TaskContentType: String, Codable, Hashable {
    case richGuide = "rich-guide"
    case comparisonGuide = "comparison-guide"
    case processGuide = "process-guide"
    case simpleText = "simple-text"
}

private struct TaskContent: Hashable, Codable {
    var type: TaskContentType
    var sections: [ContentSection]

    init(type: TaskContentType = .simpleText, sections: [ContentSection] = []) {
        self.type = type
        self.sections = sections
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(TaskContentType.self, forKey: .type) ?? .simpleText
        self.sections = try container.decodeIfPresent([ContentSection].self, forKey: .sections) ?? []
    }
}

private enum ContentSection: Hashable, Codable {
    case why(WhySectionData)
    case overview(OverviewSectionData)
    case checklist(ChecklistSectionData)
    case options(OptionsSectionData)
    case comparisonTable(OptionsSectionData)
    case tips(TipsSectionData)
    case references(ReferencesSectionData)
    case officialReferences(OfficialReferencesSectionData)
    case steps(StepsSectionData)
    case apps(AppsSectionData)
    case faqs(FAQSectionData)
    case unsupported(UnsupportedSectionData)

    private enum TypeKey: String, CodingKey {
        case type
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let typeRaw = try container.decode(String.self, forKey: .type)

        switch typeRaw {
        case "why":
            self = .why(try WhySectionData(from: decoder))
        case "overview":
            self = .overview(try OverviewSectionData(from: decoder))
        case "checklist":
            self = .checklist(try ChecklistSectionData(from: decoder))
        case "options":
            self = .options(try OptionsSectionData(from: decoder))
        case "comparison-table":
            self = .comparisonTable(try OptionsSectionData(from: decoder))
        case "tips":
            self = .tips(try TipsSectionData(from: decoder))
        case "references":
            self = .references(try ReferencesSectionData(from: decoder))
        case "official-references":
            self = .officialReferences(try OfficialReferencesSectionData(from: decoder))
        case "steps":
            self = .steps(try StepsSectionData(from: decoder))
        case "apps":
            self = .apps(try AppsSectionData(from: decoder))
        case "faqs":
            self = .faqs(try FAQSectionData(from: decoder))
        default:
            let title = try container.decodeIfPresent(String.self, forKey: .title)
            let rawPayload = try? JSONValue(from: decoder)
            self = .unsupported(
                UnsupportedSectionData(
                    type: typeRaw,
                    title: title,
                    payload: UnsupportedSectionData.extractPayload(from: rawPayload)
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .why(let value):
            try value.encode(to: encoder)
        case .overview(let value):
            try value.encode(to: encoder)
        case .checklist(let value):
            try value.encode(to: encoder)
        case .options(let value):
            try value.encode(to: encoder)
        case .comparisonTable(let value):
            var adapted = value
            adapted.type = "comparison-table"
            try adapted.encode(to: encoder)
        case .tips(let value):
            try value.encode(to: encoder)
        case .references(let value):
            try value.encode(to: encoder)
        case .officialReferences(let value):
            try value.encode(to: encoder)
        case .steps(let value):
            try value.encode(to: encoder)
        case .apps(let value):
            try value.encode(to: encoder)
        case .faqs(let value):
            try value.encode(to: encoder)
        case .unsupported(let value):
            try value.encode(to: encoder)
        }
    }
}

private struct WhySectionData: Hashable, Codable {
    var type: String = "why"
    var title: String?
    var description: String?
    var content: String
    var icon: String?
}

private struct OverviewSectionData: Hashable, Codable {
    var type: String = "overview"
    var title: String?
    var description: String?
    var content: String
}

private struct ChecklistSectionData: Hashable, Codable {
    var type: String = "checklist"
    var title: String?
    var description: String?
    var items: [String]
    var allowUserChecks: Bool?
}

private struct OptionsSectionData: Hashable, Codable {
    var type: String = "options"
    var title: String?
    var description: String?
    var items: [OptionItem]
}

private enum SourceTrustType: String, Codable, Hashable {
    case official
    case university
    case partner
    case community
    case editorial
    case unknown

    var label: String {
        switch self {
        case .official:
            return "Official"
        case .university:
            return "University"
        case .partner:
            return "Partner"
        case .community:
            return "Community"
        case .editorial:
            return "Editorial"
        case .unknown:
            return "Unverified"
        }
    }
}

private struct AudienceFilters: Hashable, Codable {
    var cities: [String] = []
    var universities: [String] = []

    var isEmpty: Bool {
        cities.isEmpty && universities.isEmpty
    }

    func matches(city: String, university: String) -> Bool {
        let normalizedCity = Self.normalize(city)
        let normalizedUniversity = Self.normalize(university)

        let cityMatch: Bool
        if cities.isEmpty || normalizedCity.isEmpty {
            cityMatch = true
        } else {
            cityMatch = cities.contains { Self.matchesFilter($0, query: normalizedCity) }
        }

        let universityMatch: Bool
        if universities.isEmpty || normalizedUniversity.isEmpty {
            universityMatch = true
        } else {
            universityMatch = universities.contains { Self.matchesFilter($0, query: normalizedUniversity) }
        }

        return cityMatch && universityMatch
    }

    private static func matchesFilter(_ rawFilter: String, query: String) -> Bool {
        let filter = normalize(rawFilter)
        guard !filter.isEmpty else { return true }
        if filter == "*" || filter == "all" {
            return true
        }
        return query.contains(filter) || filter.contains(query)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

private struct SourceMetadata: Hashable, Codable {
    var sourceType: SourceTrustType?
    var sourceName: String?
    var lastVerified: String?
    var audience: AudienceFilters?
    var note: String?

    var resolvedTrustType: SourceTrustType {
        sourceType ?? .unknown
    }

    var verifiedLabel: String? {
        guard let lastVerified, !lastVerified.isEmpty else { return nil }
        if let date = Self.isoFormatter.date(from: lastVerified) ?? Self.fallbackFormatter.date(from: lastVerified) {
            return Self.outputFormatter.string(from: date)
        }
        return lastVerified
    }

    func matchesAudience(city: String, university: String) -> Bool {
        guard let audience else { return true }
        return audience.matches(city: city, university: university)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct OptionItem: Hashable, Codable {
    var name: String
    var description: String?
    var rating: Double?
    var tags: [String] = []
    var priceLevel: String?
    var link: LinkData?
    var location: LocationData?
    var highlights: [String] = []
    var source: SourceMetadata?
    var audience: AudienceFilters?

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

private struct TipsSectionData: Hashable, Codable {
    var type: String = "tips"
    var title: String?
    var description: String?
    var items: [TipItem]
}

private struct TipItem: Hashable, Codable {
    var text: String
    var author: String?
    var upvotes: Int?
}

private struct ReferencesSectionData: Hashable, Codable {
    var type: String = "references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

private struct OfficialReferencesSectionData: Hashable, Codable {
    var type: String = "official-references"
    var title: String?
    var description: String?
    var items: [ReferenceItem]
}

private struct ReferenceItem: Hashable, Codable {
    var title: String
    var description: String?
    var url: String
    var type: String?
    var icon: String?
    var organization: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedSourceMetadata: SourceMetadata? {
        if let source {
            return source
        }

        if let type, type.lowercased() == "official" {
            return SourceMetadata(
                sourceType: .official,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        if let organization, !organization.isEmpty {
            return SourceMetadata(
                sourceType: .editorial,
                sourceName: organization,
                lastVerified: nil,
                audience: audience,
                note: nil
            )
        }

        return nil
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = resolvedSourceMetadata?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

private struct StepsSectionData: Hashable, Codable {
    var type: String = "steps"
    var title: String?
    var description: String?
    var items: [ProcessStepItem]
}

private struct ProcessStepItem: Hashable, Codable {
    var number: Int
    var title: String
    var duration: String?
    var cost: String?
    var description: String?
    var actions: [StepAction] = []
    var requirements: [String] = []
    var tips: [String] = []
}

private struct StepAction: Hashable, Codable {
    var type: String
    var label: String
    var url: String?
    var icon: String?
    var name: String?
    var cost: String?
    var searchTerm: String?
    var source: SourceMetadata?

    var resolvedURL: URL? {
        if let url, let parsed = URL(string: url) {
            return parsed
        }

        if let searchTerm, !searchTerm.isEmpty {
            let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

private struct AppsSectionData: Hashable, Codable {
    var type: String = "apps"
    var title: String?
    var description: String?
    var items: [AppRecommendationItem]
}

private struct AppRecommendationItem: Hashable, Codable {
    var name: String
    var description: String?
    var icon: String?
    var downloadLinks: AppDownloadLinks?
}

private struct AppDownloadLinks: Hashable, Codable {
    var ios: String?
    var android: String?

    var iosURL: URL? {
        guard let ios, !ios.isEmpty else { return nil }
        return URL(string: ios)
    }

    var androidURL: URL? {
        guard let android, !android.isEmpty else { return nil }
        return URL(string: android)
    }

    var primaryURL: URL? {
        iosURL ?? androidURL
    }
}

private struct FAQSectionData: Hashable, Codable {
    var type: String = "faqs"
    var title: String?
    var description: String?
    var items: [FAQItem]
}

private struct FAQItem: Hashable, Codable {
    var question: String
    var answer: String
}

private struct LinkData: Hashable, Codable {
    var type: String
    var url: String
    var label: String?
    var tracking: String?
    var source: SourceMetadata?
    var audience: AudienceFilters?

    var resolvedURL: URL? {
        URL(string: url)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let directAudienceMatch = audience?.matches(city: city, university: university) ?? true
        let sourceAudienceMatch = source?.matchesAudience(city: city, university: university) ?? true
        return directAudienceMatch && sourceAudienceMatch
    }
}

private struct LocationData: Hashable, Codable {
    var type: String
    var search: String?
    var coordinates: Coordinates?
    var address: String?

    struct Coordinates: Hashable, Codable {
        var lat: Double
        var lng: Double
    }

    var mapsURL: URL? {
        if let search, !search.isEmpty {
            let query = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        if let coordinates {
            return URL(string: "https://maps.apple.com/?ll=\(coordinates.lat),\(coordinates.lng)")
        }

        if let address, !address.isEmpty {
            let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }

        return nil
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private enum JSONValue: Hashable, Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: JSONValue] = [:]
            for key in keyedContainer.allKeys {
                object[key.stringValue] = try keyedContainer.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !unkeyedContainer.isAtEnd {
                array.append(try unkeyedContainer.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        let singleContainer = try decoder.singleValueContainer()
        if singleContainer.decodeNil() {
            self = .null
        } else if let boolValue = try? singleContainer.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? singleContainer.decode(Double.self) {
            self = .number(numberValue)
        } else if let stringValue = try? singleContainer.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: singleContainer,
                debugDescription: "Unsupported JSON payload"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let value):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, payload) in value {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try container.encode(payload, forKey: codingKey)
            }
        case .array(let value):
            var container = encoder.unkeyedContainer()
            for payload in value {
                try container.encode(payload)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

private struct UnsupportedSectionData: Hashable, Codable {
    var type: String
    var title: String?
    var payload: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case type
        case title
    }

    init(type: String, title: String?, payload: JSONValue? = nil) {
        self.type = type
        self.title = title
        self.payload = payload
    }

    static func extractPayload(from rawValue: JSONValue?) -> JSONValue? {
        guard case .object(let rawObject) = rawValue else { return nil }
        var filtered = rawObject
        filtered.removeValue(forKey: "type")
        filtered.removeValue(forKey: "title")
        return filtered.isEmpty ? nil : .object(filtered)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        let rawPayload = try? JSONValue(from: decoder)
        self.payload = Self.extractPayload(from: rawPayload)
    }

    func encode(to encoder: Encoder) throws {
        if case .object(let payloadObject) = payload {
            var mergedObject = payloadObject
            mergedObject["type"] = .string(type)
            if let title {
                mergedObject["title"] = .string(title)
            }
            try JSONValue.object(mergedObject).encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
    }
}

private struct ChecklistTask: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String?
    var isComplete: Bool
    var isCustom: Bool
    var estimatedMinutes: Int?
    var urgency: TaskUrgency
    var order: Int?
    var timing: TaskTiming
    var priority: TaskPriority
    var content: TaskContent?
    var sourceTitle: String?
    var sourceURL: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        detail: String? = nil,
        isComplete: Bool = false,
        isCustom: Bool = false,
        estimatedMinutes: Int? = nil,
        urgency: TaskUrgency = .medium,
        order: Int? = nil,
        timing: TaskTiming = .anytime,
        priority: TaskPriority = .shouldDo,
        content: TaskContent? = nil,
        sourceTitle: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.isCustom = isCustom
        self.estimatedMinutes = estimatedMinutes
        self.urgency = urgency
        self.order = order
        self.timing = timing
        self.priority = priority
        self.content = content
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case isComplete
        case isCustom
        case estimatedMinutes
        case urgency
        case order
        case timing
        case priority
        case content
        case sourceTitle
        case sourceURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        self.isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        self.urgency = try container.decodeIfPresent(TaskUrgency.self, forKey: .urgency) ?? .medium
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.timing = try container.decodeIfPresent(TaskTiming.self, forKey: .timing) ?? .anytime
        self.priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .shouldDo
        self.content = try container.decodeIfPresent(TaskContent.self, forKey: .content)
        self.sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
        self.sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(urgency, forKey: .urgency)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encode(timing, forKey: .timing)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(sourceTitle, forKey: .sourceTitle)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
    }
}

private struct ChecklistCategory: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var subtitle: String?
    var icon: String
    var gradient: [String]?
    var priority: Int?
    var priorityLevel: CategoryPriorityLevel?
    var urgency: CategoryUrgencyBand?
    var accentColorHex: String?
    var deadline: String?
    var isVisibleOverride: Bool?
    var order: Int?
    var cityFilters: [String]?
    var universityFilters: [String]?
    var unlockRequirements: String?
    var tasks: [ChecklistTask]

    var isVisible: Bool {
        isVisibleOverride ?? true
    }

    var visualPriority: CategoryPriorityLevel {
        if let priorityLevel {
            return priorityLevel
        }
        if let priority {
            return CategoryPriorityLevel.fromLegacy(priority: priority)
        }
        switch urgencyBand {
        case .immediate:
            return .critical
        case .week1:
            return .high
        case .week2:
            return .medium
        case .anytime, .completed:
            return .low
        }
    }

    var urgencyBand: CategoryUrgencyBand {
        if !tasks.isEmpty && tasks.allSatisfy(\.isComplete) {
            return .completed
        }
        if let urgency {
            return urgency
        }
        if tasks.contains(where: { $0.timing == .monthBeforeArrival || $0.timing == .weekBeforeArrival }) {
            return .immediate
        }
        if tasks.contains(where: { $0.timing == .firstWeek }) {
            return .week1
        }
        if tasks.contains(where: { $0.timing == .firstMonth }) {
            return .week2
        }
        if tasks.contains(where: { $0.priority == .mustDo }) {
            return .week1
        }
        return .anytime
    }

    var resolvedSubtitle: String {
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        if let unlockRequirements, !unlockRequirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unlockRequirements
        }
        if tasks.isEmpty {
            return "No tasks available yet"
        }
        switch urgencyBand {
        case .immediate:
            return "Must complete before arrival"
        case .week1:
            return "Important for your first week"
        case .week2:
            return "Plan this in your first month"
        case .anytime:
            return "Complete when convenient"
        case .completed:
            return "All tasks completed"
        }
    }

    var deadlineLabel: String? {
        guard let deadline, !deadline.isEmpty else {
            return nil
        }
        if let date = Self.deadlineInputFormatter.date(from: deadline) ?? Self.fallbackDeadlineFormatter.date(from: deadline) {
            return Self.deadlineOutputFormatter.string(from: date)
        }
        return deadline
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let filters = AudienceFilters(
            cities: cityFilters ?? [],
            universities: universityFilters ?? []
        )
        return filters.matches(city: city, university: university)
    }

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        gradient: [String]? = nil,
        priority: Int? = nil,
        priorityLevel: CategoryPriorityLevel? = nil,
        urgency: CategoryUrgencyBand? = nil,
        accentColorHex: String? = nil,
        deadline: String? = nil,
        isVisibleOverride: Bool? = nil,
        order: Int? = nil,
        cityFilters: [String]? = nil,
        universityFilters: [String]? = nil,
        unlockRequirements: String? = nil,
        tasks: [ChecklistTask]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
        self.priority = priority
        self.priorityLevel = priorityLevel
        self.urgency = urgency
        self.accentColorHex = accentColorHex
        self.deadline = deadline
        self.isVisibleOverride = isVisibleOverride
        self.order = order
        self.cityFilters = cityFilters
        self.universityFilters = universityFilters
        self.unlockRequirements = unlockRequirements
        self.tasks = tasks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case icon
        case gradient
        case priority
        case priorityLevel
        case visualPriority
        case urgency
        case accentColor
        case accentColorHex
        case deadline
        case isVisible
        case order
        case cityFilters
        case universityFilters
        case cities
        case universities
        case unlockRequirements
        case tasks
    }

    private static let deadlineInputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDeadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let deadlineOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "square.grid.2x2"
        self.gradient = try container.decodeIfPresent([String].self, forKey: .gradient)

        if let numericPriority = try? container.decode(Int.self, forKey: .priority) {
            self.priority = numericPriority
            self.priorityLevel = nil
        } else if let rawPriority = try? container.decode(String.self, forKey: .priority),
                  let parsedPriority = CategoryPriorityLevel(rawValue: rawPriority.lowercased()) {
            self.priority = nil
            self.priorityLevel = parsedPriority
        } else if let explicitPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .priorityLevel) {
            self.priority = nil
            self.priorityLevel = explicitPriority
        } else if let visualPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .visualPriority) {
            self.priority = nil
            self.priorityLevel = visualPriority
        } else {
            self.priority = nil
            self.priorityLevel = nil
        }

        self.urgency = try container.decodeIfPresent(CategoryUrgencyBand.self, forKey: .urgency)

        if let accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) {
            self.accentColorHex = accentColor
        } else {
            self.accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex)
        }

        self.deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        self.isVisibleOverride = try container.decodeIfPresent(Bool.self, forKey: .isVisible)
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.cityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .cityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .cities))
        self.universityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .universityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .universities))
        self.unlockRequirements = try container.decodeIfPresent(String.self, forKey: .unlockRequirements)
        self.tasks = try container.decodeIfPresent([ChecklistTask].self, forKey: .tasks) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(gradient, forKey: .gradient)
        if let priorityLevel {
            try container.encode(priorityLevel.rawValue, forKey: .priority)
        } else {
            try container.encodeIfPresent(priority, forKey: .priority)
        }
        try container.encodeIfPresent(urgency, forKey: .urgency)
        try container.encodeIfPresent(accentColorHex, forKey: .accentColor)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encodeIfPresent(isVisibleOverride, forKey: .isVisible)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(cityFilters, forKey: .cityFilters)
        try container.encodeIfPresent(universityFilters, forKey: .universityFilters)
        try container.encodeIfPresent(unlockRequirements, forKey: .unlockRequirements)
        try container.encode(tasks, forKey: .tasks)
    }
}

private enum SampleData {
    static let categories: [ChecklistCategory] = [
        ChecklistCategory(id: "before_arrival", title: "Before Arrival", icon: "airplane.departure", tasks: []),
        ChecklistCategory(id: "health_admin", title: "Health & Admin", icon: "heart.text.square", tasks: []),
        ChecklistCategory(id: "money_banking", title: "Money & Banking", icon: "banknote", tasks: []),
        ChecklistCategory(id: "travel_discounts", title: "Travel & Discounts", icon: "tram", tasks: [])
    ]
}

#Preview {
    ContentView()
}
