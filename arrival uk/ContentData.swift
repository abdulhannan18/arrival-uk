import Foundation
import Observation
import os
import SwiftUI

@Observable
final class ContentStore {
    static let shared = ContentStore()
    private static let legacyProgressStorageKey = StorageKey.contentProgressV1Legacy.rawValue
    private static let progressEncryptionKeyID = StorageKey.contentProgressEncryptionKey.rawValue
    private static let taskViewDateUpdateInterval: TimeInterval = 60

    var categories: [ChecklistCategory] = []
    private let progressKey = StorageKey.contentProgressV2Encrypted.rawValue
    private let legacyProgressKey = ContentStore.legacyProgressStorageKey
    private let progressEncryptionKey = ContentStore.progressEncryptionKeyID
    private var cachedProgressSnapshot: ContentProgressSnapshot?
    private var progressPersistTask: Task<Void, Never>?
    private var lastTaskViewDateRefreshAt: Date?
    
    private struct BundleLoadResolution {
        let categories: [ChecklistCategory]
        let event: String
    }

    @MainActor
    func loadFromBundle() async {
        LaunchMetrics.mark(event: "bundle_content_load_begin")
        let storageKey = progressKey
        let (resolution, snapshot) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resolved = Self.resolveCategoriesFromBundle()
                let snapshot = Self.decodeProgressSnapshot(storageKey: storageKey)
                continuation.resume(returning: (resolved, snapshot))
            }
        }

        cachedProgressSnapshot = snapshot
        withAnimation(.easeInOut(duration: 0.20)) {
            categories = resolution.categories
        }
        applyPersistedProgressIfAvailable()
        LaunchMetrics.mark(event: resolution.event)
    }

    @MainActor
    func primeWithSampleDataIfNeeded() {
        guard categories.isEmpty else { return }
        categories = Self.normalizedCategories(Self.sanitize(SampleData.categories))
        applyPersistedProgressIfAvailable()
        LaunchMetrics.mark(event: "bundle_content_primed_sample")
    }

    @MainActor
    func persistProgress() {
        guard !categories.isEmpty else { return }
        let snapshotComponents = Self.progressSnapshotComponents(from: categories)
        let snapshot = ContentProgressSnapshot(
            completedTaskIDs: snapshotComponents.completedTaskIDs,
            completionDatesByTaskID: snapshotComponents.completionDatesByTaskID,
            taskViewDatesByTaskID: snapshotComponents.taskViewDatesByTaskID,
            customTasksByCategory: snapshotComponents.customTasksByCategory
        )
        cachedProgressSnapshot = snapshot
        let storageKey = progressKey
        let legacyStorageKey = legacyProgressKey
        let encryptionKey = progressEncryptionKey

        progressPersistTask?.cancel()
        progressPersistTask = Task(priority: .utility) { @MainActor in
            // Coalesce rapid toggles (and avoid blocking user interactions).
            try? await Task.sleep(for: AppTiming.contentProgressPersistenceCoalescingDelay)
            guard !Task.isCancelled else { return }

            do {
                let encoded = try JSONEncoder().encode(snapshot)
                try EncryptedDefaultsStore.save(
                    encoded,
                    for: storageKey,
                    keychainKey: encryptionKey,
                    defaults: .standard
                )
                UserDefaults.standard.removeObject(forKey: legacyStorageKey)
                LaunchMetrics.mark(event: "content_progress_persisted")
            } catch {
                LaunchMetrics.mark(event: "content_progress_encrypt_failed")
                CrashReporter.record(error: error, context: "content_progress_encrypt_failed")
            }
        }
    }

    @MainActor
    func clearAllProgress() {
        progressPersistTask?.cancel()
        progressPersistTask = nil

        guard !categories.isEmpty else {
            EncryptedDefaultsStore.wipe(
                storageKey: progressKey,
                keychainKey: progressEncryptionKey,
                defaults: .standard
            )
            UserDefaults.standard.removeObject(forKey: legacyProgressKey)
            cachedProgressSnapshot = nil
            return
        }

        for categoryIndex in categories.indices {
            categories[categoryIndex].tasks.removeAll(where: \.isCustom)
            for taskIndex in categories[categoryIndex].tasks.indices {
                categories[categoryIndex].tasks[taskIndex].isComplete = false
                categories[categoryIndex].tasks[taskIndex].completedAt = nil
                categories[categoryIndex].tasks[taskIndex].lastViewedAt = nil
            }
        }

        cachedProgressSnapshot = nil
        EncryptedDefaultsStore.wipe(
            storageKey: progressKey,
            keychainKey: progressEncryptionKey,
            defaults: .standard
        )
        UserDefaults.standard.removeObject(forKey: legacyProgressKey)
    }

    @MainActor
    func updateTaskViewDates() {
        guard !categories.isEmpty else { return }

        let now = Date()
        if let lastRefresh = lastTaskViewDateRefreshAt,
           now.timeIntervalSince(lastRefresh) < Self.taskViewDateUpdateInterval {
            return
        }
        var didMutate = false

        for categoryIndex in categories.indices {
            guard let taskIndex = categories[categoryIndex].tasks.indices.first(where: { index in
                !categories[categoryIndex].tasks[index].isComplete
            }) else {
                continue
            }

            if categories[categoryIndex].tasks[taskIndex].lastViewedAt != now {
                categories[categoryIndex].tasks[taskIndex].lastViewedAt = now
                didMutate = true
            }
        }

        if didMutate {
            lastTaskViewDateRefreshAt = now
            persistProgress()
        }
    }

    static func progressSnapshotComponents(
        from categories: [ChecklistCategory]
    ) -> (
        completedTaskIDs: [String],
        completionDatesByTaskID: [String: Date],
        taskViewDatesByTaskID: [String: Date],
        customTasksByCategory: [String: [ChecklistTask]]
    ) {
        let completedTaskIDs = Set(categories
            .flatMap(\.tasks)
            .filter(\.isComplete)
            .map(\.id))
            .sorted()

        var completionDatesByTaskID: [String: Date] = [:]
        var taskViewDatesByTaskID: [String: Date] = [:]

        for task in categories.flatMap(\.tasks) {
            if let completionDate = task.completedAt {
                completionDatesByTaskID[task.id] = completionDate
            }
            if let viewDate = task.lastViewedAt {
                taskViewDatesByTaskID[task.id] = viewDate
            }
        }

        var customTasksByCategory: [String: [ChecklistTask]] = [:]
        for category in categories {
            let customTasks = deduplicateTasksByID(category.tasks.filter(\.isCustom))
            if !customTasks.isEmpty {
                customTasksByCategory[category.id] = customTasks
            }
        }

        return (completedTaskIDs, completionDatesByTaskID, taskViewDatesByTaskID, customTasksByCategory)
    }

    @MainActor
    private func applyPersistedProgressIfAvailable() {
        if let cachedProgressSnapshot {
            applyPersistedProgress(cachedProgressSnapshot)
            return
        }

        guard let snapshot = Self.decodeProgressSnapshot(storageKey: progressKey) else { return }
        cachedProgressSnapshot = snapshot
        applyPersistedProgress(snapshot)
    }

    @MainActor
    private func applyPersistedProgress(_ snapshot: ContentProgressSnapshot) {
        let completedTaskIDs = Set(snapshot.completedTaskIDs)
        var updatedCategories: [ChecklistCategory] = []

        for var category in categories {
            if let savedCustomTasks = snapshot.customTasksByCategory[category.id], !savedCustomTasks.isEmpty {
                let existingIDs = Set(category.tasks.map(\.id))
                let missingCustomTasks = Self.deduplicateTasksByID(savedCustomTasks)
                    .filter { !existingIDs.contains($0.id) }
                category.tasks.append(contentsOf: missingCustomTasks)
            }

            for index in category.tasks.indices {
                let taskID = category.tasks[index].id
                let shouldBeCompleted = completedTaskIDs.contains(taskID)
                category.tasks[index].isComplete = shouldBeCompleted
                category.tasks[index].completedAt = shouldBeCompleted ? snapshot.completionDatesByTaskID[taskID] : nil
                category.tasks[index].lastViewedAt = snapshot.taskViewDatesByTaskID[taskID]
            }

            updatedCategories.append(category)
        }

        categories = Self.normalizedCategories(updatedCategories)
        LaunchMetrics.mark(event: "content_progress_applied")
    }

    private static func deduplicateTasksByID(_ tasks: [ChecklistTask]) -> [ChecklistTask] {
        var seen = Set<String>()
        var uniqueTasks: [ChecklistTask] = []
        uniqueTasks.reserveCapacity(tasks.count)

        for task in tasks {
            guard seen.insert(task.id).inserted else { continue }
            uniqueTasks.append(task)
        }

        return uniqueTasks
    }

    private static func decodeProgressSnapshot(storageKey: String) -> ContentProgressSnapshot? {
        let defaults = UserDefaults.standard
        let encryptedKey = Self.progressEncryptionKeyID

        if let encryptedData = try? EncryptedDefaultsStore.load(
            for: storageKey,
            keychainKey: encryptedKey,
            defaults: defaults
        ) {
            return try? JSONDecoder().decode(ContentProgressSnapshot.self, from: encryptedData)
        }

        if
            let legacyData = defaults.data(forKey: Self.legacyProgressStorageKey),
            let legacySnapshot = try? JSONDecoder().decode(ContentProgressSnapshot.self, from: legacyData)
        {
            // One-time migration from plaintext progress storage to encrypted storage.
            if let encoded = try? JSONEncoder().encode(legacySnapshot) {
                try? EncryptedDefaultsStore.save(
                    encoded,
                    for: storageKey,
                    keychainKey: encryptedKey,
                    defaults: defaults
                )
                defaults.removeObject(forKey: Self.legacyProgressStorageKey)
            }
            return legacySnapshot
        }

        return nil
    }

    private static func resolveCategoriesFromBundle() -> BundleLoadResolution {
        // Fast path: prefer content.json first because it already carries structured sections.
        // Decoding only one file significantly reduces cold-start time on simulator.
        if var contentPayload = ContentPayload.loadFromBundle(named: "content"),
           !contentPayload.categories.isEmpty {
            // Ensure minimal fallback guidance is still present if structured content is partial.
            contentPayload = mergePayload(
                primary: contentPayload,
                secondary: ContentPayload(categories: SampleData.categories),
                includeFallbackOnlyTasks: false,
                includeFallbackOnlyCategories: false
            )

            let resolvedCategories = normalizedCategories(sanitize(contentPayload.categories))
            logIntegrityReport(for: resolvedCategories, source: "content")
            let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
            if totalTasks > 0 {
                return BundleLoadResolution(
                    categories: resolvedCategories,
                    event: "bundle_content_load_success_content_tasks_\(totalTasks)"
                )
            }
        }

        // Fallback path: categories.json (legacy schema) + sample enrichment for task detail guidance.
        if var categoriesPayload = ContentPayload.loadFromBundle(named: "categories"),
           !categoriesPayload.categories.isEmpty {
            categoriesPayload = mergePayload(
                primary: categoriesPayload,
                secondary: ContentPayload(categories: SampleData.categories),
                includeFallbackOnlyTasks: false,
                includeFallbackOnlyCategories: false
            )
            LaunchMetrics.mark(event: "bundle_content_enriched_with_sample_fallback")

            let resolvedCategories = normalizedCategories(sanitize(categoriesPayload.categories))
            logIntegrityReport(for: resolvedCategories, source: "categories")
            let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
            if totalTasks > 0 {
                return BundleLoadResolution(
                    categories: resolvedCategories,
                    event: "bundle_content_load_success_categories_tasks_\(totalTasks)"
                )
            }
        }

        let resolvedCategories = normalizedCategories(sanitize(SampleData.categories))
        logIntegrityReport(for: resolvedCategories, source: "sample")
        let totalTasks = resolvedCategories.reduce(0) { $0 + $1.tasks.count }
        let event = totalTasks > 0
            ? "bundle_content_load_fallback_sample_tasks_\(totalTasks)"
            : "bundle_content_load_fallback_sample_empty_tasks"
        return BundleLoadResolution(categories: resolvedCategories, event: event)
    }

    private static func normalizedCategories(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
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

    private static func sanitize(_ input: [ChecklistCategory]) -> [ChecklistCategory] {
        var seenCategoryIDs: Set<String> = []
        var output: [ChecklistCategory] = []

        for var category in input {
            let categoryID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonicalCategoryID = canonical(categoryID)
            let categoryTitle = category.title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !categoryID.isEmpty, !categoryTitle.isEmpty else {
                continue
            }

            guard !seenCategoryIDs.contains(canonicalCategoryID) else {
                continue
            }

            seenCategoryIDs.insert(canonicalCategoryID)
            category.title = categoryTitle

            if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                category.icon = AppCategory.resolve(categoryID: canonicalCategoryID, fallbackTitle: categoryTitle)?.iconSystemName ?? "square.grid.2x2"
            }

            let subtitleTrimmed = category.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if subtitleTrimmed.isEmpty, let mappedCategory = AppCategory.resolve(categoryID: canonicalCategoryID, fallbackTitle: categoryTitle) {
                category.subtitle = mappedCategory.subtitle
            }

            var seenTaskIDs: Set<String> = []
            var cleanedTasks: [ChecklistTask] = []

            for var task in category.tasks {
                let taskID = task.id.trimmingCharacters(in: .whitespacesAndNewlines)
                let canonicalTaskID = canonical(taskID)
                let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !taskID.isEmpty, !taskTitle.isEmpty else {
                    continue
                }

                guard !seenTaskIDs.contains(canonicalTaskID) else {
                    continue
                }

                seenTaskIDs.insert(canonicalTaskID)
                task.title = taskTitle
                task.detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                task.content = normalizedTaskContent(for: task)
                cleanedTasks.append(task)
            }

            category.tasks = cleanedTasks
            output.append(category)
        }

        return output
    }

    private static func mergePayload(
        primary: ContentPayload,
        secondary: ContentPayload,
        includeFallbackOnlyTasks: Bool = false,
        includeFallbackOnlyCategories: Bool = false
    ) -> ContentPayload {
        var secondaryByID: [String: ChecklistCategory] = [:]
        var secondaryByTitle: [String: ChecklistCategory] = [:]

        for category in secondary.categories {
            let canonicalID = canonical(category.id)
            let canonicalTitle = canonical(category.title)
            if secondaryByID[canonicalID] == nil {
                secondaryByID[canonicalID] = category
            }
            if secondaryByTitle[canonicalTitle] == nil {
                secondaryByTitle[canonicalTitle] = category
            }
        }

        var mergedCategories: [ChecklistCategory] = []
        var seenMergedKeys: Set<String> = []

        for category in primary.categories {
            var mergedCategory = category
            let lookupID = canonical(category.id)
            let lookupTitle = canonical(category.title)
            if seenMergedKeys.contains(lookupID) || seenMergedKeys.contains(lookupTitle) {
                continue
            }

            let fallbackCategory = secondaryByID[lookupID] ?? secondaryByTitle[lookupTitle]
            if let fallbackCategory {
                mergedCategory = mergeCategory(
                    primary: mergedCategory,
                    fallback: fallbackCategory,
                    includeFallbackOnlyTasks: includeFallbackOnlyTasks
                )
            }

            mergedCategories.append(mergedCategory)
            seenMergedKeys.insert(lookupID)
            seenMergedKeys.insert(lookupTitle)
        }

        if includeFallbackOnlyCategories {
            for fallbackCategory in secondary.categories {
                let fallbackID = canonical(fallbackCategory.id)
                let fallbackTitle = canonical(fallbackCategory.title)
                if seenMergedKeys.contains(fallbackID) || seenMergedKeys.contains(fallbackTitle) {
                    continue
                }
                mergedCategories.append(fallbackCategory)
            }
        }

        return ContentPayload(categories: mergedCategories)
    }

    private static func mergeCategory(
        primary: ChecklistCategory,
        fallback: ChecklistCategory,
        includeFallbackOnlyTasks: Bool = false
    ) -> ChecklistCategory {
        var merged = primary

        if (merged.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.subtitle = fallback.subtitle
        }

        if (merged.categoryType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.categoryType = fallback.categoryType
        }

        if merged.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || merged.icon == "square.grid.2x2" {
            merged.icon = fallback.icon
        }

        if merged.priority == nil && merged.priorityLevel == nil {
            merged.priority = fallback.priority
            merged.priorityLevel = fallback.priorityLevel
        }

        if merged.urgency == nil {
            merged.urgency = fallback.urgency
        }

        if (merged.accentColorHex?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.accentColorHex = fallback.accentColorHex
        }

        if (merged.deadline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.deadline = fallback.deadline
        }

        if merged.order == nil {
            merged.order = fallback.order
        }

        if merged.cityFilters?.isEmpty ?? true {
            merged.cityFilters = fallback.cityFilters
        }

        if merged.universityFilters?.isEmpty ?? true {
            merged.universityFilters = fallback.universityFilters
        }

        if (merged.unlockRequirements?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.unlockRequirements = fallback.unlockRequirements
        }

        if merged.tasks.isEmpty {
            merged.tasks = fallback.tasks
            return merged
        }

        var fallbackTasksByID: [String: ChecklistTask] = [:]
        var fallbackTasksByTitle: [String: ChecklistTask] = [:]
        for fallbackTask in fallback.tasks {
            let canonicalID = canonical(fallbackTask.id)
            if fallbackTasksByID[canonicalID] == nil {
                fallbackTasksByID[canonicalID] = fallbackTask
            }

            let canonicalTitle = canonical(fallbackTask.title)
            if fallbackTasksByTitle[canonicalTitle] == nil {
                fallbackTasksByTitle[canonicalTitle] = fallbackTask
            }
        }

        var mergedTasks: [ChecklistTask] = []
        var mergedTaskIdentifiers: Set<String> = []
        var mergedTaskTitles: Set<String> = []

        for task in merged.tasks {
            let taskID = canonical(task.id)
            let taskTitle = canonical(task.title)

            if let fallbackTask = fallbackTasksByID[taskID] ?? fallbackTasksByTitle[taskTitle] {
                let mergedTask = mergeTask(primary: task, fallback: fallbackTask)
                mergedTasks.append(mergedTask)
                mergedTaskIdentifiers.insert(canonical(mergedTask.id))
                mergedTaskTitles.insert(canonical(mergedTask.title))
            } else {
                mergedTasks.append(task)
                mergedTaskIdentifiers.insert(taskID)
                mergedTaskTitles.insert(taskTitle)
            }
        }

        if includeFallbackOnlyTasks {
            for fallbackTask in fallback.tasks {
                let fallbackID = canonical(fallbackTask.id)
                let fallbackTitle = canonical(fallbackTask.title)
                if mergedTaskIdentifiers.contains(fallbackID) || mergedTaskTitles.contains(fallbackTitle) {
                    continue
                }
                mergedTasks.append(fallbackTask)
                mergedTaskIdentifiers.insert(fallbackID)
                mergedTaskTitles.insert(fallbackTitle)
            }
        }

        merged.tasks = mergedTasks
        return merged
    }

    private static func mergeTask(primary: ChecklistTask, fallback: ChecklistTask) -> ChecklistTask {
        var merged = primary

        if merged.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.title = fallback.title
        }

        if (merged.detail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.detail = fallback.detail
        }

        if merged.estimatedMinutes == nil {
            merged.estimatedMinutes = fallback.estimatedMinutes
        }

        if merged.order == nil {
            merged.order = fallback.order
        }

        if (merged.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.sourceTitle = fallback.sourceTitle
        }

        if (merged.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            merged.sourceURL = fallback.sourceURL
        }

        if merged.timing == .anytime && fallback.timing != .anytime {
            merged.timing = fallback.timing
        }

        if merged.priority == .shouldDo && fallback.priority != .shouldDo {
            merged.priority = fallback.priority
        }

        if merged.urgency == .medium && fallback.urgency != .medium {
            merged.urgency = fallback.urgency
        }

        let primarySectionCount = merged.content?.sections.count ?? 0
        let fallbackSectionCount = fallback.content?.sections.count ?? 0
        if fallbackSectionCount > primarySectionCount {
            merged.content = fallback.content
        }

        return merged
    }

    private static func normalizedTaskContent(for task: ChecklistTask) -> TaskContent? {
        if let existingContent = task.content, !existingContent.sections.isEmpty {
            return existingContent
        }

        var sections: [ContentSection] = []
        if let detail = task.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            sections.append(
                .overview(
                    OverviewSectionData(
                        title: "Overview",
                        description: nil,
                        content: detail
                    )
                )
            )

            let steps = fallbackStepItems(for: detail)
            if !steps.isEmpty {
                sections.append(
                    .steps(
                        StepsSectionData(
                            type: "steps",
                            title: "Step-by-step",
                            description: nil,
                            items: steps
                        )
                    )
                )
            }
        }

        let tips = fallbackTips(for: task)
        if !tips.isEmpty {
            sections.append(
                .tips(
                    TipsSectionData(
                        type: "tips",
                        title: "Tips",
                        description: nil,
                        items: tips
                    )
                )
            )
        }

        if let rawSourceURL = task.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawSourceURL.isEmpty,
           let validatedSourceURL = ExternalURLPolicy.normalizedURL(from: rawSourceURL) {
            let sourceTitle = task.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let referenceTitle = sourceTitle?.isEmpty == false ? sourceTitle ?? "Official guidance" : "Official guidance"
            sections.append(
                .references(
                    ReferencesSectionData(
                        type: "references",
                        title: "Official resources",
                        description: nil,
                        items: [
                            ReferenceItem(
                                title: referenceTitle,
                                description: "Open the latest official guidance for this task.",
                                url: validatedSourceURL.absoluteString,
                                type: "official",
                                icon: nil,
                                organization: nil,
                                source: SourceMetadata(
                                    sourceType: .official,
                                    sourceName: nil,
                                    lastVerified: nil,
                                    audience: nil,
                                    note: nil
                                ),
                                audience: nil
                            )
                        ]
                    )
                )
            )
        }

        guard !sections.isEmpty else { return task.content }
        return TaskContent(type: .richGuide, sections: sections)
    }

    private static func fallbackStepItems(for detail: String) -> [ProcessStepItem] {
        let normalized = detail
            .replacingOccurrences(of: " and ", with: ", ")
            .replacingOccurrences(of: "•", with: ", ")

        let parts = normalized
            .split(whereSeparator: { [",", ";", "\n"].contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        if parts.isEmpty {
            return []
        }

        if parts.count == 1 {
            return [
                ProcessStepItem(
                    number: 1,
                    title: parts[0],
                    duration: nil,
                    cost: nil,
                    description: nil,
                    actions: [],
                    requirements: [],
                    tips: []
                )
            ]
        }

        return parts.enumerated().map { index, value in
            ProcessStepItem(
                number: index + 1,
                title: value,
                duration: nil,
                cost: nil,
                description: nil,
                actions: [],
                requirements: [],
                tips: []
            )
        }
    }

    private static func fallbackTips(for task: ChecklistTask) -> [TipItem] {
        var tips: [TipItem] = []

        if task.priority == .mustDo {
            tips.append(
                TipItem(
                    text: "Prioritize this task before optional items to avoid early delays.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        if task.timing != .anytime {
            tips.append(
                TipItem(
                    text: "Complete this \(task.timing.label.lowercased()) so you avoid last-minute issues.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        if task.sourceURL != nil {
            tips.append(
                TipItem(
                    text: "Use the official source link to verify the latest requirements before submission.",
                    author: nil,
                    upvotes: nil
                )
            )
        }

        return tips
    }

    private static func canonical(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func logIntegrityReport(for categories: [ChecklistCategory], source: String) {
        let categoryIDs = categories.map { canonical($0.id) }
        let uniqueCategoryIDs = Set(categoryIDs)
        let duplicateCategoryCount = max(0, categoryIDs.count - uniqueCategoryIDs.count)
        let emptyCategoryCount = categories.filter { $0.tasks.isEmpty }.count
        let totalTasks = categories.reduce(0) { $0 + $1.tasks.count }

        LaunchMetrics.mark(
            event: "content_integrity_\(source)_c\(categories.count)_t\(totalTasks)_empty\(emptyCategoryCount)_dup\(duplicateCategoryCount)"
        )
    }
}

private nonisolated struct ContentProgressSnapshot: Codable {
    var version: Int
    var completedTaskIDs: [String]
    var completionDatesByTaskID: [String: Date]
    var taskViewDatesByTaskID: [String: Date]
    var customTasksByCategory: [String: [ChecklistTask]]

    init(
        version: Int = 3,
        completedTaskIDs: [String],
        completionDatesByTaskID: [String: Date],
        taskViewDatesByTaskID: [String: Date],
        customTasksByCategory: [String: [ChecklistTask]]
    ) {
        self.version = version
        self.completedTaskIDs = completedTaskIDs
        self.completionDatesByTaskID = completionDatesByTaskID
        self.taskViewDatesByTaskID = taskViewDatesByTaskID
        self.customTasksByCategory = customTasksByCategory
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case completedTaskIDs
        case completionDatesByTaskID
        case taskViewDatesByTaskID
        case customTasksByCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        completedTaskIDs = try container.decodeIfPresent([String].self, forKey: .completedTaskIDs) ?? []
        completionDatesByTaskID = try container.decodeIfPresent([String: Date].self, forKey: .completionDatesByTaskID) ?? [:]
        taskViewDatesByTaskID = try container.decodeIfPresent([String: Date].self, forKey: .taskViewDatesByTaskID) ?? [:]
        customTasksByCategory = try container.decodeIfPresent([String: [ChecklistTask]].self, forKey: .customTasksByCategory) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(completedTaskIDs, forKey: .completedTaskIDs)
        try container.encode(completionDatesByTaskID, forKey: .completionDatesByTaskID)
        try container.encode(taskViewDatesByTaskID, forKey: .taskViewDatesByTaskID)
        try container.encode(customTasksByCategory, forKey: .customTasksByCategory)
    }
}
