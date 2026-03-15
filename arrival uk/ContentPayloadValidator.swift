import Foundation
import os

struct ContentPayload: Codable {
    let categories: [ChecklistCategory]

    private static let payloadCacheLock = NSLock()
    private static var cachedPayloadByFile: [String: ContentPayload] = [:]

    static func loadFromBundle(named fileName: String) -> ContentPayload? {
        if let cachedPayload = cachedPayload(for: fileName) {
            LaunchMetrics.mark(event: "bundle_content_cache_hit")
            return cachedPayload
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            LaunchMetrics.mark(event: "bundle_content_missing_file")
            CrashReporter.log("bundle content missing file=\(fileName)", level: .error)
            return nil
        }

        let decodeStart = Date()

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            LaunchMetrics.mark(event: "bundle_content_read_failed")
            CrashReporter.log("bundle content read failed file=\(fileName)", level: .error)
            return nil
        }

        let decoder = JSONDecoder()
        let payload: ContentPayload
        do {
            payload = try decoder.decode(ContentPayload.self, from: data)
        } catch {
            CrashReporter.record(
                error: error,
                context: "content_decode",
                metadata: ["file": fileName]
            )
            #if DEBUG
            let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
                category: "startup"
            )
            logger.debug("bundle_content_decode_error file=\(fileName, privacy: .public) error=\(String(describing: error), privacy: .public)")
            #endif

            if let recoveredPayload = decodeLossyPayload(from: data, fileName: fileName) {
                setCachedPayload(recoveredPayload, for: fileName)
                LaunchMetrics.mark(event: "bundle_content_decode_recovered_lossy")
                return recoveredPayload
            }

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

        setCachedPayload(payload, for: fileName)
        let elapsed = Date().timeIntervalSince(decodeStart)
        LaunchMetrics.mark(event: "bundle_content_decode_success_\(Int(elapsed * 1000))ms")
        return payload
    }

    private static func cachedPayload(for fileName: String) -> ContentPayload? {
        payloadCacheLock.lock()
        defer { payloadCacheLock.unlock() }
        return cachedPayloadByFile[fileName]
    }

    private static func setCachedPayload(_ payload: ContentPayload, for fileName: String) {
        payloadCacheLock.lock()
        cachedPayloadByFile[fileName] = payload
        payloadCacheLock.unlock()
    }

    private static func decodeLossyPayload(from data: Data, fileName: String) -> ContentPayload? {
        guard
            let rootObject = try? JSONSerialization.jsonObject(with: data),
            let rootDict = rootObject as? [String: Any],
            let rawCategories = rootDict["categories"] as? [Any],
            !rawCategories.isEmpty
        else {
            return nil
        }

        let decoder = JSONDecoder()
        var decodedCategories: [ChecklistCategory] = []

        for (categoryIndex, rawCategory) in rawCategories.enumerated() {
            guard JSONSerialization.isValidJSONObject(rawCategory) else { continue }
            guard let categoryData = try? JSONSerialization.data(withJSONObject: rawCategory) else { continue }

            if let category = try? decoder.decode(ChecklistCategory.self, from: categoryData) {
                decodedCategories.append(category)
                continue
            }

            // Fallback: decode category shell and recover valid tasks one by one.
            guard let categoryDict = rawCategory as? [String: Any] else { continue }

            let id = (categoryDict["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = (categoryDict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let categoryID = id, !categoryID.isEmpty, let categoryTitle = title, !categoryTitle.isEmpty else {
                continue
            }

            var recoveredTasks: [ChecklistTask] = []
            if let rawTasks = categoryDict["tasks"] as? [Any] {
                for rawTask in rawTasks {
                    guard JSONSerialization.isValidJSONObject(rawTask) else { continue }
                    guard let taskData = try? JSONSerialization.data(withJSONObject: rawTask) else { continue }
                    if let task = try? decoder.decode(ChecklistTask.self, from: taskData) {
                        recoveredTasks.append(task)
                    }
                }
            }

            let recoveredCategory = ChecklistCategory(
                id: categoryID,
                title: categoryTitle,
                subtitle: categoryDict["subtitle"] as? String,
                categoryType: (categoryDict["type"] as? String) ?? (categoryDict["categoryType"] as? String),
                icon: (categoryDict["icon"] as? String) ?? "square.grid.2x2",
                gradient: categoryDict["gradient"] as? [String],
                priority: categoryDict["priority"] as? Int,
                priorityLevel: CategoryPriorityLevel(rawValue: ((categoryDict["priority"] as? String) ?? "").lowercased()) ??
                    CategoryPriorityLevel(rawValue: ((categoryDict["priorityLevel"] as? String) ?? "").lowercased()) ??
                    CategoryPriorityLevel(rawValue: ((categoryDict["visualPriority"] as? String) ?? "").lowercased()),
                urgency: CategoryUrgencyBand(rawValue: ((categoryDict["urgency"] as? String) ?? "").lowercased()),
                accentColorHex: (categoryDict["accentColor"] as? String) ?? (categoryDict["accentColorHex"] as? String),
                deadline: categoryDict["deadline"] as? String,
                isVisibleOverride: categoryDict["isVisible"] as? Bool,
                order: categoryDict["order"] as? Int,
                cityFilters: (categoryDict["cityFilters"] as? [String]) ?? (categoryDict["cities"] as? [String]),
                universityFilters: (categoryDict["universityFilters"] as? [String]) ?? (categoryDict["universities"] as? [String]),
                unlockRequirements: categoryDict["unlockRequirements"] as? String,
                tasks: recoveredTasks
            )
            decodedCategories.append(recoveredCategory)

            #if DEBUG
            let logger = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
                category: "startup"
            )
            logger.debug("bundle_content_decode_lossy_category file=\(fileName, privacy: .public) index=\(categoryIndex, privacy: .public)")
            #endif
        }

        guard !decodedCategories.isEmpty else { return nil }

        #if DEBUG
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
            category: "startup"
        )
        logger.debug("bundle_content_decode_lossy_success file=\(fileName, privacy: .public) categories=\(decodedCategories.count, privacy: .public)")
        #endif

        return ContentPayload(categories: decodedCategories)
    }
}

enum ContentIssueSeverity: String {
    case warning
    case error
}

struct ContentValidationIssue: Hashable {
    let severity: ContentIssueSeverity
    let path: String
    let message: String
}

struct ContentValidationReport {
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

enum ContentValidator {
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
        let canonicalCategoryID = canonicalIdentifier(categoryID)
        if categoryID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Category id is empty."))
        } else if seenCategoryIDs.contains(canonicalCategoryID) {
            issues.append(
                issue(.error, path: "\(path).id", message: "Duplicate category id '\(categoryID)'.")
            )
        } else {
            seenCategoryIDs.insert(canonicalCategoryID)
        }

        if category.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue(.error, path: "\(path).title", message: "Category title is empty."))
        }

        let hasAutoMappableIcon = AppCategory.resolve(categoryID: categoryID, fallbackTitle: category.title) != nil
        if category.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasAutoMappableIcon {
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
        let canonicalTaskID = canonicalIdentifier(taskID)
        if taskID.isEmpty {
            issues.append(issue(.error, path: "\(path).id", message: "Task id is empty."))
        } else if seenTaskIDs.contains(canonicalTaskID) {
            issues.append(issue(.error, path: "\(path).id", message: "Duplicate task id '\(taskID)'."))
        } else {
            seenTaskIDs.insert(canonicalTaskID)
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

        guard let content = task.content else {
            issues.append(
                issue(
                    .warning,
                    path: "\(path).content",
                    message: "Task has no structured content; runtime fallback guidance will be generated."
                )
            )
            return
        }
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
        guard let url = ExternalURLPolicy.normalizedURL(from: urlString) else {
            issues.append(issue(.error, path: path, message: "Invalid URL '\(urlString)'."))
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

            if !ExternalURLPolicy.isTrustedOfficialOrUniversityHost(host) {
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

    private static func issue(
        _ severity: ContentIssueSeverity,
        path: String,
        message: String
    ) -> ContentValidationIssue {
        ContentValidationIssue(severity: severity, path: path, message: message)
    }

    private static func canonicalIdentifier(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
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
