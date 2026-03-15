import XCTest
@testable import arrival_uk

@MainActor
final class Phase8ScalabilityTests: XCTestCase {
    func testTaskPriorityDomainNextTasksReturnsSurvivalBeforeMaintenance() {
        let survival = makeAppTask(id: "survival", urgencyBand: .immediate, priority: .mustDo)
        let maintenance = makeAppTask(id: "maintenance", urgencyBand: .anytime, priority: .optional)

        let topTasks = TaskPriorityDomain.nextTasks(
            fromQueues: [survival],
            maintenance: [maintenance],
            limit: 3
        )

        XCTAssertEqual(topTasks.map(\.id), ["survival", "maintenance"])
    }

    func testTaskPriorityDomainSettledModeProducesEmptyQueues() {
        let categories = [
            ChecklistCategory(
                id: "academic_setup",
                title: "Academic Setup",
                icon: "graduationcap.fill",
                urgency: .immediate,
                tasks: [
                    ChecklistTask(id: "task-1", title: "Register modules", priority: .mustDo)
                ]
            )
        ]

        let queues = TaskPriorityDomain.partitionAndSort(from: categories, isSettledMode: true)

        XCTAssertTrue(queues.survival.isEmpty)
        XCTAssertTrue(queues.maintenance.isEmpty)
    }

    func testUKLocaleFormatUsesUKDateAndCurrencyConventions() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2026
        components.month = 3
        components.day = 2

        let date = components.date ?? .distantPast
        let dateString = UKLocaleFormat.mediumDateString(date)
        let currency = UKLocaleFormat.currencyString(Decimal(42))

        XCTAssertEqual(dateString, "2 Mar 2026")
        XCTAssertEqual(currency, "£42.00")
    }

    private func makeAppTask(
        id: String,
        urgencyBand: CategoryUrgencyBand,
        priority: TaskPriority
    ) -> AppTask {
        AppTask(
            id: id,
            taskID: id,
            categoryID: "cat-\(id)",
            categoryTitle: "Category \(id)",
            title: "Task \(id)",
            detail: nil,
            symbolName: "checkmark.circle",
            urgency: .medium,
            priority: priority,
            timing: .anytime,
            dueDate: nil,
            categoryUrgency: urgencyBand,
            categoryOrder: 0,
            taskOrder: 0
        )
    }
}
