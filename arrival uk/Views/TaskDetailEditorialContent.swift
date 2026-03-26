import SwiftUI

struct TaskDetailEditorialContent: Hashable {
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

enum TaskDetailContentResolver {
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
