import Foundation

typealias Category = ChecklistCategory
typealias CategoryTask = ChecklistTask

extension ChecklistCategory {
    var taskCount: Int {
        tasks.count
    }

    var totalTaskCount: Int {
        tasks.count
    }

    var completedCount: Int {
        tasks.reduce(0) { partialResult, task in
            partialResult + (task.isComplete ? 1 : 0)
        }
    }

    var completionRatio: Double {
        guard taskCount > 0 else { return 0 }
        return Double(completedCount) / Double(taskCount)
    }

    var remainingTaskCount: Int {
        max(0, totalTaskCount - completedCount)
    }

    var mostRecentCompletionDate: Date? {
        tasks.compactMap(\.completedAt).max()
    }

    var estimatedMinutes: Int {
        let scoped = tasks.filter { !$0.isComplete }
        let source = scoped.isEmpty ? tasks : scoped
        let total = source.reduce(0) { partial, task in
            partial + max(1, task.estimatedMinutes ?? 0)
        }
        return max(total, max(source.count, 1) * 5)
    }

    var isCompleted: Bool {
        taskCount > 0 && completedCount == taskCount
    }

    var nextIncompleteTask: ChecklistTask? {
        tasks
            .sorted { lhs, rhs in
                let leftOrder = lhs.order ?? .max
                let rightOrder = rhs.order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return lhs.id < rhs.id
            }
            .first(where: { !$0.isComplete })
    }

    var sfSymbolName: String {
        resolvedIconSystemName
    }

    var urgencyLevel: UrgencyLevel {
        switch urgencyBand {
        case .immediate:
            return .overdue
        case .week1:
            return .upcoming
        case .week2, .anytime, .completed:
            return .none
        }
    }
}

extension ChecklistTask {
    var isCompleted: Bool {
        get { isComplete }
        set { isComplete = newValue }
    }

    var descriptionText: String {
        detail ?? ""
    }

    var timingText: String {
        timing.label
    }
}
