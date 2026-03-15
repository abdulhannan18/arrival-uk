import Foundation

struct AppTask: Identifiable, Hashable {
    let id: String
    let taskID: String
    let categoryID: String
    let categoryTitle: String
    let title: String
    let detail: String?
    let symbolName: String
    let urgency: TaskUrgency
    let priority: TaskPriority
    let timing: TaskTiming
    let dueDate: Date?
    let categoryUrgency: CategoryUrgencyBand
    let categoryOrder: Int
    let taskOrder: Int
}
