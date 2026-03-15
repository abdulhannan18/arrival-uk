import Foundation

enum TaskPriorityDomain {
    static func partitionAndSort(
        from categories: [ChecklistCategory],
        isSettledMode: Bool,
        regionConfiguration: RegionConfiguration = RegionRuntime.activeConfiguration
    ) -> (survival: [AppTask], maintenance: [AppTask]) {
        guard !isSettledMode else {
            return ([], [])
        }

        let projectedTasks = projectTasks(from: categories)
        var survival: [AppTask] = []
        var maintenance: [AppTask] = []

        for task in projectedTasks {
            if isSurvivalTask(task, regionConfiguration: regionConfiguration) {
                survival.append(task)
            } else {
                maintenance.append(task)
            }
        }

        sortTasksInPlace(&survival, regionConfiguration: regionConfiguration)
        sortTasksInPlace(&maintenance, regionConfiguration: regionConfiguration)

        return (survival, maintenance)
    }

    static func nextTasks(
        from categories: [ChecklistCategory],
        limit: Int,
        isSettledMode: Bool,
        regionConfiguration: RegionConfiguration = RegionRuntime.activeConfiguration
    ) -> [AppTask] {
        guard limit > 0 else { return [] }

        let queues = partitionAndSort(
            from: categories,
            isSettledMode: isSettledMode,
            regionConfiguration: regionConfiguration
        )
        return Array((queues.survival + queues.maintenance).prefix(limit))
    }

    static func nextTasks(
        fromQueues survival: [AppTask],
        maintenance: [AppTask],
        limit: Int
    ) -> [AppTask] {
        guard limit > 0 else { return [] }
        return Array((survival + maintenance).prefix(limit))
    }

    static func isSurvivalTask(
        _ task: AppTask,
        regionConfiguration: RegionConfiguration = RegionRuntime.activeConfiguration
    ) -> Bool {
        if task.categoryUrgency == .immediate || task.categoryUrgency == .week1 {
            return true
        }

        if task.priority == .mustDo {
            return true
        }

        if task.urgency == .high {
            return true
        }

        if task.timing == .monthBeforeArrival || task.timing == .weekBeforeArrival {
            return true
        }

        return matchesRegionalPriority(task, regionConfiguration: regionConfiguration)
    }

    static func sortTasks(
        lhs: AppTask,
        rhs: AppTask,
        regionConfiguration: RegionConfiguration = RegionRuntime.activeConfiguration
    ) -> Bool {
        if lhs.categoryUrgency.ranking != rhs.categoryUrgency.ranking {
            return lhs.categoryUrgency.ranking < rhs.categoryUrgency.ranking
        }

        let lhsRegionalBoost = regionalBoostRanking(for: lhs, regionConfiguration: regionConfiguration)
        let rhsRegionalBoost = regionalBoostRanking(for: rhs, regionConfiguration: regionConfiguration)
        if lhsRegionalBoost != rhsRegionalBoost {
            return lhsRegionalBoost < rhsRegionalBoost
        }

        if priorityRanking(lhs.priority) != priorityRanking(rhs.priority) {
            return priorityRanking(lhs.priority) < priorityRanking(rhs.priority)
        }

        if timingRanking(lhs.timing) != timingRanking(rhs.timing) {
            return timingRanking(lhs.timing) < timingRanking(rhs.timing)
        }

        switch (lhs.dueDate, rhs.dueDate) {
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

        if lhs.categoryOrder != rhs.categoryOrder {
            return lhs.categoryOrder < rhs.categoryOrder
        }

        if lhs.taskOrder != rhs.taskOrder {
            return lhs.taskOrder < rhs.taskOrder
        }

        return lhs.id < rhs.id
    }

    private static func projectTasks(from categories: [ChecklistCategory]) -> [AppTask] {
        var tasks: [AppTask] = []
        tasks.reserveCapacity(categories.reduce(0) { $0 + $1.tasks.count })

        for category in categories {
            let categoryOrder = category.order ?? .max
            let categoryTitle = RegionRuntime.semanticLocalized(category.title)

            for task in category.tasks where !task.isComplete {
                tasks.append(
                    AppTask(
                        id: task.id,
                        taskID: task.id,
                        categoryID: category.id,
                        categoryTitle: categoryTitle,
                        title: RegionRuntime.semanticLocalized(task.title),
                        detail: task.detail.map { RegionRuntime.semanticLocalized($0) },
                        symbolName: category.resolvedIconSystemName,
                        urgency: task.urgency,
                        priority: task.priority,
                        timing: task.timing,
                        dueDate: task.dueDate,
                        categoryUrgency: category.urgencyBand,
                        categoryOrder: categoryOrder,
                        taskOrder: task.order ?? .max
                    )
                )
            }
        }

        return tasks
    }

    private static func priorityRanking(_ priority: TaskPriority) -> Int {
        switch priority {
        case .mustDo:
            return 0
        case .shouldDo:
            return 1
        case .optional:
            return 2
        }
    }

    private static func timingRanking(_ timing: TaskTiming) -> Int {
        switch timing {
        case .monthBeforeArrival:
            return 0
        case .weekBeforeArrival:
            return 1
        case .firstWeek:
            return 2
        case .firstMonth:
            return 3
        case .ongoing:
            return 4
        case .anytime:
            return 5
        }
    }

    private static func sortTasksInPlace(
        _ tasks: inout [AppTask],
        regionConfiguration: RegionConfiguration
    ) {
        guard tasks.count > 1 else { return }

        for index in 1..<tasks.count {
            var cursor = index
            let current = tasks[cursor]
            while cursor > 0 && sortTasks(
                lhs: current,
                rhs: tasks[cursor - 1],
                regionConfiguration: regionConfiguration
            ) {
                tasks[cursor] = tasks[cursor - 1]
                cursor -= 1
            }
            tasks[cursor] = current
        }
    }

    private static func matchesRegionalPriority(
        _ task: AppTask,
        regionConfiguration: RegionConfiguration
    ) -> Bool {
        let keywords = regionConfiguration.survivalTaskBoostKeywords
        guard !keywords.isEmpty else { return false }
        let searchable = searchableText(for: task)
        return keywords.contains(where: { keyword in
            searchable.contains(keyword)
        })
    }

    private static func regionalBoostRanking(
        for task: AppTask,
        regionConfiguration: RegionConfiguration
    ) -> Int {
        matchesRegionalPriority(task, regionConfiguration: regionConfiguration) ? 0 : 1
    }

    private static func searchableText(for task: AppTask) -> String {
        [task.title, task.detail ?? "", task.categoryTitle]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
