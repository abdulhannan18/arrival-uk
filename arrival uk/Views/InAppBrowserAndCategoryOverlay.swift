import SwiftUI
import UIKit
import SafariServices
import AuthenticationServices

private enum CategoryOverlayLocalization {
    private static var languageCode: String {
        Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased() ?? "en"
    }

    private static var isUrdu: Bool {
        languageCode == "ur"
    }

    private static var isArabic: Bool {
        languageCode == "ar"
    }

    private static func pick(en: String, ur: String, ar: String) -> String {
        if isUrdu { return ur }
        if isArabic { return ar }
        return en
    }

    static var tasksTitle: String {
        pick(en: "Tasks", ur: "ٹاسکس", ar: "المهام")
    }
}

struct InAppBrowserSheet: View {
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

struct CategoryDetailOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    @Binding var category: ChecklistCategory
    let allCategories: [ChecklistCategory]
    let namespace: Namespace.ID
    let heroID: String
    let prefersReducedMotion: Bool
    let onClose: () -> Void
    let onToggleTask: () -> Void
    let onOpenTaskGuide: () -> Void
    let requestedTaskID: String?
    let onTaskGuideRequestConsumed: () -> Void

    @State private var headerBrightness: Double = 0
    @State private var heroOrbPhase = false
    @State private var selectedTaskID: String?
    @Namespace private var taskHeroNamespace

    private var categoryListIndex: Int {
        allCategories.firstIndex(where: { $0.id == category.id }) ?? 0
    }

    private var orbTheme: CategoryOrbTheme {
        CategoryColorSystem.orbTheme(for: category, index: categoryListIndex)
    }

    private var accentColor: Color {
        Color(hex: orbTheme.accentHex)
    }

    private var heroHint: String {
        let explicitSubtitle = (category.subtitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicitSubtitle.isEmpty {
            return explicitSubtitle
        }
        return category.resolvedDefaultSubtitle
    }

    private var heroTitle: String {
        formattedTitle(from: category.title)
    }

    private var stats: CategoryStats {
        CategoryStats(tasks: category.tasks)
    }

    private var tasksHeaderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : rgba(10, 10, 18, 0.92)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            dashboardSurface
                .scaleEffect(selectedTaskID != nil ? 0.93 : 1)
                .opacity(selectedTaskID != nil ? 0.86 : 1)
                .cornerRadius(selectedTaskID != nil ? 32 : 0)
                .ignoresSafeArea(.all, edges: selectedTaskID != nil ? .all : [])
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: selectedTaskID)

            if let selectedTaskBinding {
                SmartNoteGuideView(
                    task: selectedTaskBinding,
                    animation: taskHeroNamespace,
                    onDismiss: dismissExpandedTask,
                    onTaskCompletionPersist: onToggleTask
                )
                .transition(.identity)
                .zIndex(2)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            HapticService.shared.prepare()
            startHeroOrbAnimationIfNeeded()
            consumeExternalTaskGuideRequestIfNeeded(requestedTaskID)
        }
        .onChange(of: category.tasks.map(\.id)) { _, taskIDs in
            guard let selectedTaskID else { return }
            if !taskIDs.contains(selectedTaskID) {
                self.selectedTaskID = nil
            }
        }
        .onChange(of: requestedTaskID) { _, taskID in
            consumeExternalTaskGuideRequestIfNeeded(taskID)
        }
    }

    private var dashboardSurface: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                detailHeroHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(CategoryOverlayLocalization.tasksTitle.uppercased())
                            .font(ArrivalTypography.figtree(size: 8.5, weight: .bold))
                            .tracking(1.9)
                            .foregroundStyle(tasksHeaderColor)
                            .padding(.horizontal, Theme.spaceXL)
                            .padding(.top, 18)
                            .padding(.bottom, 8)

                        TaskListView(
                            category: $category,
                            accentColor: accentColor,
                            dotColor: orbTheme.dotColor,
                            showsScrollContainer: false,
                            heroNamespace: taskHeroNamespace,
                            selectedTaskID: selectedTaskID,
                            onScroll: { _ in },
                            onTaskCompletionPersist: onToggleTask,
                            onCategoryComplete: handleLastTaskCompletion,
                            onOpenGuide: { task in
                                openTaskGuide(taskID: task.id)
                            }
                        )
                    }
                    .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? Theme.spaceXXL : Theme.spaceL)
                }
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private var detailHeroHeader: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(colorScheme == .dark ? rgba(22, 22, 35, 0.94) : Color(UIColor.secondarySystemGroupedBackground))
                .matchedGeometryEffect(id: "category-card-\(heroID)", in: namespace)
                .ignoresSafeArea(edges: .top)

            GeometryReader { proxy in
                Circle()
                    .fill(orbTheme.orbGradient)
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.width * 1.2)
                    .offset(
                        x: proxy.size.width * 0.30 + (heroOrbPhase ? 12 : 0),
                        y: -proxy.size.height * 0.42 + (heroOrbPhase ? -8 : 0)
                    )
            }
            .clipShape(Rectangle())
            .matchedGeometryEffect(id: "category-hero-shape-\(heroID)", in: namespace)
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.52))
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.70))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 52)

                Spacer(minLength: 0)

                Text(heroHint)
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.66))
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "category-subtitle-\(heroID)", in: namespace)

                Text(heroTitle)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(colorScheme == .dark ? Color.white : rgba(10, 10, 18, 1))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .matchedGeometryEffect(id: "category-title-\(heroID)", in: namespace)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            Color.clear
                .frame(width: 1, height: 1)
                .matchedGeometryEffect(id: "category-icon-\(heroID)", in: namespace)
                .accessibilityHidden(true)
        }
        .frame(height: 280)
        .brightness(headerBrightness)
    }

    private func startHeroOrbAnimationIfNeeded() {
        guard !prefersReducedMotion else { return }

        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
            heroOrbPhase = true
        }
    }

    private func handleLastTaskCompletion() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                headerBrightness = 0.15
            }

            withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
                headerBrightness = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            HapticService.shared.heavy()
        }
    }

    private var selectedTaskBinding: Binding<ChecklistTask>? {
        guard let selectedTaskID else { return nil }
        guard let index = category.tasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            return nil
        }
        return $category.tasks[index]
    }

    private func openTaskGuide(taskID: String) {
        onOpenTaskGuide()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedTaskID = taskID
        }
    }

    private func dismissExpandedTask() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedTaskID = nil
        }
    }

    private func consumeExternalTaskGuideRequestIfNeeded(_ taskID: String?) {
        guard let taskID else { return }
        guard category.tasks.contains(where: { $0.id == taskID }) else {
            onTaskGuideRequestConsumed()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedTaskID = taskID
        }
        onTaskGuideRequestConsumed()
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


struct BottomModalOverlay<Content: View>: View {
    let maxHeightRatio: CGFloat
    let minHeightRatio: CGFloat
    let prefersReducedMotion: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        maxHeightRatio: CGFloat,
        minHeightRatio: CGFloat = 0.45,
        prefersReducedMotion: Bool,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxHeightRatio = maxHeightRatio
        self.minHeightRatio = minHeightRatio
        self.prefersReducedMotion = prefersReducedMotion
        self.onDismiss = onDismiss
        self.content = content
    }

    @GestureState private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let safeRatio = min(max(maxHeightRatio, minHeightRatio), 0.95)
            let baseSheetHeight = min(proxy.size.height * safeRatio, 760)
            let keyboardTopY = proxy.size.height - keyboardHeight
            let maxHeightAboveKeyboard = keyboardHeight > 0
                ? max(180, keyboardTopY - proxy.safeAreaInsets.top - Theme.spaceL)
                : baseSheetHeight
            let sheetHeight = min(baseSheetHeight, maxHeightAboveKeyboard)
            let bottomInset = max(proxy.safeAreaInsets.bottom, Theme.spaceS)
            let bottomPadding = keyboardHeight > 0
                ? keyboardHeight + Theme.spaceS
                : bottomInset
            let dismissDragGesture = DragGesture(minimumDistance: 3)
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 140 {
                        onDismiss()
                    }
                }

            ZStack(alignment: .bottom) {
                ModalBackdrop(onDismiss: onDismiss)
                    .zIndex(0)
                    .allowsHitTesting(true)

                VStack(spacing: 0) {
                    Capsule(style: .continuous)
                        .fill(Theme.strokeStrong)
                        .frame(width: 36, height: 5)
                        .padding(.top, Theme.spaceS)
                        .padding(.bottom, Theme.spaceXS)
                        .padding(.horizontal, Theme.spaceXL)
                        .contentShape(Rectangle())
                        .gesture(dismissDragGesture)
                        .accessibilityHidden(true)

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .frame(height: sheetHeight, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .fill(Theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                )
                .shadow(color: Theme.shadowElevated, radius: 16, x: 0, y: -2)
                .offset(y: max(0, dragOffset))
                .padding(.horizontal, Theme.spaceM)
                .padding(.bottom, bottomPadding)
                .zIndex(1)
                .allowsHitTesting(true)
            }
            .task(id: proxy.size.height) {
                await observeKeyboard(containerHeight: proxy.size.height)
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
        .zIndex(LayerZIndex.modal)
    }

    private func observeKeyboard(containerHeight: CGFloat) async {
        for await notification in NotificationCenter.default.notifications(
            named: UIResponder.keyboardWillChangeFrameNotification
        ) {
            guard let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                continue
            }

            let visibleHeight = max(0, containerHeight - frameValue.origin.y)

            if prefersReducedMotion {
                keyboardHeight = visibleHeight
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    keyboardHeight = visibleHeight
                }
            }
        }
    }
}
