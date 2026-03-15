import SwiftUI
import UIKit
import SafariServices
import Combine

struct TaskDetailSheet: View {
    let task: ChecklistTask
    var onClose: (() -> Void)? = nil
    var onMarkTaskComplete: ((String) -> Void)? = nil

    @StateObject private var viewModel: TaskDetailEditorialViewModel

    init(
        task: ChecklistTask,
        onClose: (() -> Void)? = nil,
        onMarkTaskComplete: ((String) -> Void)? = nil
    ) {
        self.task = task
        self.onClose = onClose
        self.onMarkTaskComplete = onMarkTaskComplete
        _viewModel = StateObject(wrappedValue: TaskDetailEditorialViewModel(task: task))
    }

    var body: some View {
        TaskDetailEditorialView(
            content: viewModel.content,
            onClose: { onClose?() },
            onMarkComplete: { onMarkTaskComplete?(task.id) }
        )
    }
}

struct SmartNoteGuideView: View {
    @Binding var task: ChecklistTask
    let animation: Namespace.ID
    let onDismiss: () -> Void
    var onTaskCompletionPersist: () -> Void = {}

    @State private var showSafari = false
    @State private var timelineSteps: [GuideTimelineStep]

    init(
        task: Binding<ChecklistTask>,
        animation: Namespace.ID,
        onDismiss: @escaping () -> Void,
        onTaskCompletionPersist: @escaping () -> Void = {}
    ) {
        self._task = task
        self.animation = animation
        self.onDismiss = onDismiss
        self.onTaskCompletionPersist = onTaskCompletionPersist
        _timelineSteps = State(initialValue: GuideTimelineStep.make(from: task.wrappedValue))
    }

    private var editorialContent: TaskDetailEditorialContent {
        TaskDetailContentResolver.makeContent(from: task)
    }

    private var guideSubtitle: String {
        editorialContent.subtitle?.trimmedNonEmpty ?? "Smart guide workspace"
    }

    private var activeStepIDs: [UUID] {
        timelineSteps.filter { !$0.isCompleted }.map(\.id)
    }

    private var completedStepIDs: [UUID] {
        timelineSteps.filter(\.isCompleted).map(\.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .zIndex(1)

            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(activeStepIDs, id: \.self) { stepID in
                            if let step = stepBinding(for: stepID) {
                                TimelineStepView(
                                    isCompleted: step.isCompleted,
                                    title: step.wrappedValue.title,
                                    description: step.wrappedValue.description,
                                    isLast: stepID == activeStepIDs.last
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity,
                                        removal: .scale(scale: 0.92).combined(with: .opacity)
                                    )
                                )
                            }
                        }
                    }
                    .padding(.top, 12)

                    if !completedStepIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("COMPLETED")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                                .padding(.top, 28)
                                .padding(.bottom, 10)

                            ForEach(completedStepIDs, id: \.self) { stepID in
                                if let step = stepBinding(for: stepID) {
                                    TimelineStepView(
                                        isCompleted: step.isCompleted,
                                        title: step.wrappedValue.title,
                                        description: step.wrappedValue.description,
                                        isLast: stepID == completedStepIDs.last
                                    )
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity
                                        )
                                    )
                                }
                            }
                        }
                    }

                    if editorialContent.officialSourceURL != nil {
                        Button {
                            HapticService.shared.light()
                            showSafari = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Open UK Gov Portal")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(16)
                            .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(Color.purple)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    Button {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                            task.isCompleted.toggle()
                            task.completedAt = task.isCompleted ? Date() : nil
                        }
                        onTaskCompletionPersist()
                    } label: {
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                            Text(task.isCompleted ? "Mark task as active" : "Mark task complete")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .background(Color(UIColor.systemBackground))
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showSafari) {
            if let sourceURL = editorialContent.officialSourceURL {
                TaskDetailSafariView(url: sourceURL)
                    .ignoresSafeArea()
                    .presentationDetents([.fraction(0.5), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let projectedVelocity = value.predictedEndTranslation.height - value.translation.height
                    if value.translation.height > AppTheme.Layout.smartGuideDismissTranslationThreshold &&
                        projectedVelocity > AppTheme.Layout.smartGuideDismissProjectedVelocityThreshold {
                        HapticService.shared.soft()
                        withAnimation(
                            .spring(
                                response: AppTheme.Layout.smartGuideDismissSpringResponse,
                                dampingFraction: AppTheme.Layout.smartGuideDismissSpringDamping
                            )
                        ) {
                            onDismiss()
                        }
                    }
                }
        )
        .onChange(of: task.id) { _, _ in
            timelineSteps = GuideTimelineStep.make(from: task)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.84), value: timelineSteps)
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .matchedGeometryEffect(id: "task-row-bg-\(task.id)", in: animation, isSource: false)
                .ignoresSafeArea(edges: .top)

            GeometryReader { geo in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.82), Color.purple.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                    .offset(x: geo.size.width * 0.32, y: -geo.size.height * 0.42)
            }
            .clipShape(Rectangle())
            .matchedGeometryEffect(id: "task-row-orb-\(task.id)", in: animation, isSource: false)
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    HapticService.shared.soft()
                    withAnimation(
                        .spring(
                            response: AppTheme.Layout.smartGuideDismissSpringResponse,
                            dampingFraction: AppTheme.Layout.smartGuideDismissSpringDamping
                        )
                    ) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.42))
                        .background(Circle().fill(Color.white.opacity(0.66)))
                }
                .buttonStyle(.plain)
                .padding(.top, 52)

                Spacer(minLength: 0)

                Text(guideSubtitle)
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.62))
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "task-row-subtitle-\(task.id)", in: animation, isSource: false)

                Text(task.title)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .matchedGeometryEffect(id: "task-row-title-\(task.id)", in: animation, isSource: false)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(height: 280)
    }

    private func stepBinding(for id: UUID) -> Binding<GuideTimelineStep>? {
        guard let index = timelineSteps.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $timelineSteps[index]
    }
}

private struct GuideTimelineStep: Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, description: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
    }

    static func make(from task: ChecklistTask) -> [GuideTimelineStep] {
        let content = TaskDetailContentResolver.makeContent(from: task)
        let steps = content.steps
        if steps.isEmpty {
            return [
                GuideTimelineStep(
                    title: "Review official guidance",
                    description: "Read the latest official instructions before you submit anything."
                ),
                GuideTimelineStep(
                    title: "Prepare your documents",
                    description: "Keep your passport, BRP, and university records available while completing this task."
                ),
                GuideTimelineStep(
                    title: "Complete and verify",
                    description: "Submit each requirement one-by-one, then verify all fields and confirmation messages."
                )
            ]
        }

        return steps.enumerated().map { index, raw in
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                return GuideTimelineStep(
                    title: "Step \(index + 1)",
                    description: "Follow the required instruction for this step."
                )
            }

            if let colonRange = cleaned.range(of: ":") {
                let title = cleaned[..<colonRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let description = cleaned[colonRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty, !description.isEmpty {
                    return GuideTimelineStep(title: title, description: description)
                }
            }

            if let sentenceBreak = cleaned.range(of: ". ") {
                let title = cleaned[..<sentenceBreak.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let description = cleaned[sentenceBreak.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if title.count > 6, !description.isEmpty {
                    return GuideTimelineStep(title: title, description: description)
                }
            }

            return GuideTimelineStep(
                title: "Step \(index + 1)",
                description: cleaned
            )
        }
    }
}

private struct TimelineStepView: View {
    @Binding var isCompleted: Bool
    let title: String
    let description: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Button {
                    HapticService.shared.medium()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCompleted.toggle()
                    }
                } label: {
                    Circle()
                        .strokeBorder(isCompleted ? Color.purple : Color.gray.opacity(0.4), lineWidth: 2)
                        .background(Circle().fill(isCompleted ? Color.purple : Color.clear))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(isCompleted ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 2)
                        .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isCompleted ? Color.gray : Color.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(isCompleted ? Color.gray.opacity(0.65) : Color(UIColor.darkGray))
                    .lineSpacing(6)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }
}

private final class TaskDetailEditorialViewModel: ObservableObject {
    @Published var content: TaskDetailEditorialContent

    init(task: ChecklistTask) {
        self.content = TaskDetailContentResolver.makeContent(from: task)
    }
}

private struct TaskDetailEditorialContent: Hashable {
    let title: String
    let subtitle: String?
    let steps: [String]
    let tips: [String]
    let estimatedTimeLabel: String
    let priorityLabel: String
    let iconSystemName: String
    let iconTint: Color
    let officialSourceURL: URL?
    let officialSourceName: String?
}

private enum TaskDetailContentResolver {
    static func makeContent(from task: ChecklistTask) -> TaskDetailEditorialContent {
        let steps = resolveSteps(for: task)

        return TaskDetailEditorialContent(
            title: task.title,
            subtitle: resolveSubtitle(for: task),
            steps: steps,
            tips: resolveTips(for: task),
            estimatedTimeLabel: resolveEstimatedTimeLabel(for: task),
            priorityLabel: resolvePriorityLabel(for: task),
            iconSystemName: resolveIconSystemName(for: task),
            iconTint: resolveIconTint(for: task),
            officialSourceURL: resolveOfficialURL(for: task),
            officialSourceName: resolveOfficialSourceName(for: task)
        )
    }

    private static func resolveSubtitle(for task: ChecklistTask) -> String? {
        if let detail = task.detail?.trimmedNonEmpty {
            return detail.taskDetailShortSummary(maxLength: 140)
        }

        guard let content = task.content else { return nil }
        for section in content.sections {
            switch section {
            case .overview(let data):
                if let summary = data.content.trimmedNonEmpty {
                    return summary.taskDetailShortSummary(maxLength: 140)
                }
            case .why(let data):
                if let summary = data.content.trimmedNonEmpty {
                    return summary.taskDetailShortSummary(maxLength: 140)
                }
            default:
                continue
            }
        }

        return nil
    }

    private static func resolveEstimatedTimeLabel(for task: ChecklistTask) -> String {
        if let cockpitMinutes = task.taskDetailContent?.estimatedTime, cockpitMinutes > 0 {
            return "~\(cockpitMinutes) mins"
        }

        let minutes = max(1, task.estimatedMinutes ?? 12)
        return "~\(minutes) mins"
    }

    private static func resolvePriorityLabel(for task: ChecklistTask) -> String {
        task.priority.label
    }

    private static func resolveIconSystemName(for task: ChecklistTask) -> String {
        let corpus = [task.title, task.detail]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if corpus.contains("bank") || corpus.contains("money") || corpus.contains("finance") || corpus.contains("tax") {
            return "banknote.fill"
        }

        if corpus.contains("health") || corpus.contains("doctor") || corpus.contains("nhs") || corpus.contains("insurance") {
            return "cross.case.fill"
        }

        if corpus.contains("visa") || corpus.contains("legal") || corpus.contains("document") || corpus.contains("brp") {
            return "doc.text.magnifyingglass"
        }

        if corpus.contains("travel") || corpus.contains("transport") || corpus.contains("train") || corpus.contains("bus") {
            return "tram.fill"
        }

        return "doc.text.fill"
    }

    private static func resolveIconTint(for task: ChecklistTask) -> Color {
        let corpus = [task.title, task.detail]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if corpus.contains("bank") || corpus.contains("money") || corpus.contains("finance") {
            return .green
        }

        if corpus.contains("health") || corpus.contains("doctor") || corpus.contains("nhs") {
            return .red
        }

        if corpus.contains("travel") || corpus.contains("transport") {
            return .teal
        }

        if corpus.contains("legal") || corpus.contains("visa") || corpus.contains("document") {
            return .purple
        }

        return Theme.brandPrimary
    }

    private static func resolveSteps(for task: ChecklistTask) -> [String] {
        let directGuideSteps = task.guideSteps
            .compactMap { $0.trimmedNonEmpty }
        if !directGuideSteps.isEmpty {
            return directGuideSteps
        }

        if let cockpitSteps = task.taskDetailContent?.preFlightChecks, !cockpitSteps.isEmpty {
            let mapped = cockpitSteps
                .map(\.title)
                .compactMap { $0.trimmedNonEmpty }
            if !mapped.isEmpty {
                return mapped
            }
        }

        if let content = task.content {
            for section in content.sections {
                switch section {
                case .steps(let data):
                    let mapped = data.items.compactMap { item -> String? in
                        let title = item.title.trimmedNonEmpty
                        let detail = item.description?.trimmedNonEmpty

                        if let title, let detail {
                            return "\(title). \(detail)"
                        }

                        return title ?? detail
                    }
                    if !mapped.isEmpty {
                        return mapped
                    }
                case .checklist(let data):
                    let mapped = data.items
                        .compactMap { $0.trimmedNonEmpty }
                    if !mapped.isEmpty {
                        return mapped
                    }
                default:
                    continue
                }
            }
        }

        if let detail = task.detail?.trimmedNonEmpty {
            let chunks = detail.taskDetailSentenceChunks(limit: 4)
            if !chunks.isEmpty {
                return chunks
            }
        }

        return [
            "Read the official instructions carefully before submitting anything.",
            "Keep your passport, BRP, and university details ready.",
            "Complete each requirement one at a time and verify before finishing."
        ]
    }

    private static func resolveTips(for task: ChecklistTask) -> [String] {
        var tips: [String] = task.tips.compactMap { $0.trimmedNonEmpty }

        if tips.isEmpty, let content = task.content {
            for section in content.sections {
                if case .tips(let data) = section {
                    tips.append(contentsOf: data.items.compactMap { $0.text.trimmedNonEmpty })
                }
            }
        }

        if tips.isEmpty {
            if task.priority == .mustDo {
                tips.append("Complete this as early as possible to avoid delays later.")
            }

            if task.sourceURL?.trimmedNonEmpty != nil {
                tips.append("Use the official source link to avoid outdated or unofficial instructions.")
            }

            if tips.isEmpty {
                tips.append("Keep your details exactly as shown on your official documents.")
            }
        }

        var uniqueTips: [String] = []
        for tip in tips {
            guard !uniqueTips.contains(tip) else { continue }
            uniqueTips.append(tip.taskDetailShortSummary(maxLength: 140))
            if uniqueTips.count == 3 { break }
        }

        return uniqueTips
    }

    private static func resolveOfficialURL(for task: ChecklistTask) -> URL? {
        if let directURL = task.officialSourceURL?.trimmedNonEmpty,
           let normalized = ExternalURLPolicy.normalizedURL(from: directURL) {
            return normalized
        }

        if let cockpitURL = task.taskDetailContent?.actionURL?.trimmedNonEmpty,
           let normalized = ExternalURLPolicy.normalizedURL(from: cockpitURL) {
            return normalized
        }

        if let sourceURL = task.sourceURL?.trimmedNonEmpty,
           let normalized = ExternalURLPolicy.normalizedURL(from: sourceURL) {
            return normalized
        }

        guard let content = task.content else { return nil }

        for section in content.sections {
            switch section {
            case .officialReferences(let data):
                if let candidate = data.items.first?.url.trimmedNonEmpty,
                   let normalized = ExternalURLPolicy.normalizedURL(from: candidate) {
                    return normalized
                }
            case .references(let data):
                if let candidate = data.items.first?.url.trimmedNonEmpty,
                   let normalized = ExternalURLPolicy.normalizedURL(from: candidate) {
                    return normalized
                }
            case .steps(let data):
                for step in data.items {
                    for action in step.actions {
                        if let rawURL = action.url?.trimmedNonEmpty,
                           let normalized = ExternalURLPolicy.normalizedURL(from: rawURL) {
                            return normalized
                        }
                    }
                }
            case .options(let data), .comparisonTable(let data):
                for item in data.items {
                    if let rawURL = item.link?.url.trimmedNonEmpty,
                       let normalized = ExternalURLPolicy.normalizedURL(from: rawURL) {
                        return normalized
                    }
                }
            case .apps(let data):
                for app in data.items {
                    if let rawURL = app.downloadLinks?.primaryURL?.absoluteString.trimmedNonEmpty,
                       let normalized = ExternalURLPolicy.normalizedURL(from: rawURL) {
                        return normalized
                    }
                }
            default:
                continue
            }
        }

        return nil
    }

    private static func resolveOfficialSourceName(for task: ChecklistTask) -> String? {
        if let officialSourceName = task.officialSourceName?.trimmedNonEmpty {
            return officialSourceName
        }

        if let title = task.sourceTitle?.trimmedNonEmpty {
            return title
        }

        guard let content = task.content else { return nil }

        for section in content.sections {
            switch section {
            case .officialReferences(let data):
                if let first = data.items.first {
                    return first.organization?.trimmedNonEmpty ?? first.title.trimmedNonEmpty
                }
            case .references(let data):
                if let first = data.items.first {
                    return first.organization?.trimmedNonEmpty ?? first.title.trimmedNonEmpty
                }
            default:
                continue
            }
        }

        return nil
    }
}

private struct TaskDetailEditorialView: View {
    let content: TaskDetailEditorialContent
    let onClose: () -> Void
    let onMarkComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSourceBrowser = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showIntroLightRay = false
    @State private var expandedStepIndices: Set<Int> = []

    private var cardSpacing: CGFloat { interpolated(from: 34, to: 28) }
    private var horizontalMargin: CGFloat { 28 }
    private var collapseThreshold: CGFloat { 126 }
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / collapseThreshold, 0), 1)
    }
    private var visualCollapseProgress: CGFloat {
        smoothstep(collapseProgress)
    }
    private var headerSpacing: CGFloat { interpolated(from: 12, to: 10) }
    private var headerIconSize: CGFloat { interpolated(from: 60, to: 50) }
    private var headerTitleSize: CGFloat { interpolated(from: 28, to: 24) }
    private var subtitleSize: CGFloat { interpolated(from: 17, to: 16) }
    private var subtitleOpacity: Double {
        Double(max(0, 1 - (visualCollapseProgress * 0.95)))
    }
    private var subtitleMaxHeight: CGFloat { interpolated(from: 68, to: 22) }
    private var metadataOpacity: Double {
        Double(max(0, 1 - (visualCollapseProgress * 1.05)))
    }
    private var metadataMaxHeight: CGFloat { interpolated(from: 42, to: 22) }
    private var compactTopPadding: CGFloat { interpolated(from: 24, to: 20) }
    private var stickyFooterReservedHeight: CGFloat {
        hasOfficialSource ? 100 : 0
    }

    private var hasOfficialSource: Bool {
        content.officialSourceURL != nil
    }

    var body: some View {
        ZStack {
            TaskDetailParchmentBackdrop(
                parallaxOffset: reduceMotion ? 0 : max(-8, min(8, -scrollOffset * 0.015))
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceXXXL) {
                    HStack {
                        Button {
                            HapticManager.play(.light)
                            onClose()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(AppFastButtonStyle())

                        Spacer()
                    }

                    PremiumBankCardMaterial(material: .standard, showsShadow: false, contentPadding: 24) {
                        VStack(alignment: .leading, spacing: cardSpacing) {
                            headerSection

                            if hasOfficialSource {
                                OfficialSourceTrustBadge(sourceName: content.officialSourceName)
                            }

                            stepsSection
                        }
                    }
                }
                .padding(.horizontal, horizontalMargin)
                .padding(.top, compactTopPadding)
                .padding(.bottom, Theme.spaceXXXL + stickyFooterReservedHeight)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TaskDetailScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("task-detail-scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "task-detail-scroll")
            .background(ScrollViewDecelerationConfigurator(rate: .fast))
            .onPreferenceChange(TaskDetailScrollOffsetPreferenceKey.self) { value in
                scrollOffset = max(0, -value)
            }
            .overlay(alignment: .top) {
                if showIntroLightRay {
                    TaskDetailIntroLightRay()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasOfficialSource {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(height: stickyFooterReservedHeight)

                    officialSourceStickyBar
                        .padding(.horizontal, horizontalMargin)
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showSourceBrowser) {
            if let sourceURL = content.officialSourceURL {
                TaskDetailSafariView(url: sourceURL)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            HapticManager.play(.light)
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                showIntroLightRay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.42)) {
                    showIntroLightRay = false
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            PremiumIcon(
                systemName: content.iconSystemName,
                primary: content.iconTint,
                size: headerIconSize
            )

            Text(content.title)
                .font(.system(size: headerTitleSize, weight: .bold, design: .serif))
                .foregroundStyle(Theme.navy900.opacity(0.96))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(visualCollapseProgress > 0.90 ? 1 : 2)

            if let subtitle = content.subtitle {
                Text(subtitle)
                    .font(.system(size: subtitleSize, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(subtitleOpacity)
                    .frame(maxHeight: subtitleMaxHeight, alignment: .topLeading)
                    .clipped()
            }

            HStack(spacing: 8) {
                Label(content.estimatedTimeLabel, systemImage: "hourglass")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))

                Text(content.priorityLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            }
            .opacity(metadataOpacity)
            .frame(maxHeight: metadataMaxHeight, alignment: .topLeading)
            .clipped()
        }
        .animation(.easeOut(duration: 0.18), value: collapseProgress)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("How To Do This")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.navy900.opacity(0.90))

            ForEach(Array(content.steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, step: step)
            }
        }
    }

    private var officialSourceStickyBar: some View {
        Button {
            guard content.officialSourceURL != nil else { return }
            HapticManager.play(.medium)
            showSourceBrowser = true
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 17, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Official UK Source\(sourceSuffix)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))

                    Text("Official UK government source — opens in Safari")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.78), lineWidth: 1.2)
                    )
            )
            .foregroundStyle(Theme.primaryText)
        }
        .buttonStyle(AppFastButtonStyle())
        .accessibilityHint("Opens the official source in the in-app browser")
    }

    private var sourceSuffix: String {
        guard let sourceName = content.officialSourceName?.trimmedNonEmpty else {
            return ""
        }
        return " — \(sourceName)"
    }

    private func stepRow(index: Int, step: String) -> some View {
        let isExpanded = expandedStepIndices.contains(index)
        let canExpand = step.canBeExpandedForTaskDetail

        return HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 28, alignment: .leading)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(step)
                    .font(.system(size: 15, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.navy900.opacity(0.92))
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isExpanded)

                if canExpand {
                    Button {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            if isExpanded {
                                expandedStepIndices.remove(index)
                            } else {
                                expandedStepIndices.insert(index)
                            }
                        }
                        HapticManager.play(.light)
                    } label: {
                        Text(isExpanded ? "Show less" : "Read full how-to")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.brandPrimary)
                    }
                    .buttonStyle(AppFastButtonStyle())
                }
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1). \(step)")
    }

    private func interpolated(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + ((end - start) * visualCollapseProgress)
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct OfficialSourceTrustBadge: View {
    let sourceName: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.successMain)

            Text(sourceName.map { "Official source: \($0)" } ?? "Official UK source")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }
}

private struct TaskDetailParchmentBackdrop: View {
    let parallaxOffset: CGFloat

    var body: some View {
        ZStack {
            Theme.cream200
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.20), Color.white.opacity(0.0)],
                center: .topLeading,
                startRadius: 8,
                endRadius: 420
            )
            .offset(x: 36, y: -100 + parallaxOffset * 0.8)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.92, blue: 0.86).opacity(0.06),
                    Color.clear,
                    Color(red: 0.94, green: 0.90, blue: 0.83).opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ParchmentGrainLayer()
                .opacity(0.03)
                .ignoresSafeArea()
        }
    }
}

private struct ParchmentGrainLayer: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 0xC0FFEE)

            for _ in 0..<120 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let diameter = CGFloat.random(in: 0.8...1.8, using: &generator)
                let opacity = Double.random(in: 0.006...0.020, using: &generator)
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(opacity)))
            }
        }
        .blendMode(.softLight)
    }
}

private struct TaskDetailIntroLightRay: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.12), Color.white.opacity(0.00)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 96)
        .blur(radius: 8)
    }
}

private struct TaskDetailSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct TaskDetailScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum TaskDetailFeedbackType {
    case light
    case medium
}

private enum HapticManager {
    static func play(_ type: TaskDetailFeedbackType) {
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }

        switch type {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: 0.8)
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred(intensity: 0.9)
        }
    }
}

private struct ScrollViewDecelerationConfigurator: UIViewRepresentable {
    let rate: UIScrollView.DecelerationRate

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.async {
            applyRate(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            applyRate(from: uiView)
        }
    }

    private func applyRate(from view: UIView) {
        guard let scrollView = view.nearestScrollView else { return }
        if scrollView.decelerationRate != rate {
            scrollView.decelerationRate = rate
        }
    }
}

private extension UIView {
    var nearestScrollView: UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var canBeExpandedForTaskDetail: Bool {
        count > 72
    }

    func taskDetailSentenceChunks(limit: Int) -> [String] {
        let normalized = replacingOccurrences(of: "\n", with: " ")
        let chunks = normalized
            .split(whereSeparator: { [".", "!", "?"].contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if chunks.isEmpty {
            return [trimmingCharacters(in: .whitespacesAndNewlines)]
                .compactMap { $0.isEmpty ? nil : $0 }
        }

        return Array(chunks.prefix(max(1, limit)))
    }

    func taskDetailShortSummary(maxLength: Int) -> String {
        let cleaned = replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > maxLength else { return cleaned }
        return cleaned.prefix(maxLength).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
