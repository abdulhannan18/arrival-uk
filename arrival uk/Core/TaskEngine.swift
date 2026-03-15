import Observation

@Observable
final class TaskEngine {
    // Tier 1: Survival (The Swipeable Stack) - High Priority
    var survivalQueue: [AppTask] = []

    // Tier 2: Maintenance (The High-Density List) - Standard Priority
    var maintenanceTasks: [AppTask] = []
    var isSettledMode = false
    var phase3Config = Phase3Config.default
    var regionConfiguration = RegionRuntime.activeConfiguration

    func setSettledMode(_ enabled: Bool) {
        isSettledMode = enabled
        if enabled {
            survivalQueue = []
            maintenanceTasks = []
        }
    }

    func refresh(from categories: [ChecklistCategory]) {
        let queues = TaskPriorityDomain.partitionAndSort(
            from: categories,
            isSettledMode: isSettledMode,
            regionConfiguration: regionConfiguration
        )
        survivalQueue = queues.survival
        maintenanceTasks = queues.maintenance
    }

    func completeTopTask() {
        guard !survivalQueue.isEmpty else { return }
        survivalQueue.removeFirst()
    }

    func nextTasks(limit: Int = 3) -> [AppTask] {
        TaskPriorityDomain.nextTasks(
            fromQueues: survivalQueue,
            maintenance: maintenanceTasks,
            limit: limit
        )
    }

    func apply(config: Phase3Config) {
        phase3Config = config
    }

    func apply(regionConfiguration: RegionConfiguration) {
        self.regionConfiguration = regionConfiguration
    }
}
