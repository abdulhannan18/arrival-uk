import Foundation

struct ChecklistStats {
    let totalTasks: Int
    let completedTasks: Int

    var overallProgress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    init(categories: [ChecklistCategory]) {
        var total = 0
        var completed = 0

        for category in categories {
            total += category.tasks.count
            completed += category.tasks.reduce(0) { partialResult, task in
                partialResult + (task.isComplete ? 1 : 0)
            }
        }

        self.totalTasks = total
        self.completedTasks = completed
    }
}

struct CategoryStats {
    let totalCount: Int
    let completedCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    init(tasks: [ChecklistTask]) {
        self.totalCount = tasks.count
        self.completedCount = tasks.reduce(0) { partialResult, task in
            partialResult + (task.isComplete ? 1 : 0)
        }
    }
}

enum TaskTiming: String, Codable, Hashable {
    case monthBeforeArrival = "month_before_arrival"
    case weekBeforeArrival = "week_before_arrival"
    case firstWeek = "first_week"
    case firstMonth = "first_month"
    case ongoing = "ongoing"
    case anytime = "anytime"

    var label: String {
        switch self {
        case .monthBeforeArrival:
            return "About a month before"
        case .weekBeforeArrival:
            return "About a week before"
        case .firstWeek:
            return "First week"
        case .firstMonth:
            return "First month"
        case .ongoing:
            return "Ongoing"
        case .anytime:
            return "Anytime"
        }
    }
}

enum TaskPriority: String, Codable, Hashable {
    case mustDo = "must_do"
    case shouldDo = "should_do"
    case optional = "optional"

    var label: String {
        switch self {
        case .mustDo:
            return "Must do"
        case .shouldDo:
            return "Should do"
        case .optional:
            return "Optional"
        }
    }
}

enum TaskUrgency: String, Codable, Hashable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:
            return "High urgency"
        case .medium:
            return "Medium urgency"
        case .low:
            return "Low urgency"
        }
    }
}

struct ChecklistTask: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var detail: String?
    var isComplete: Bool
    var completedAt: Date?
    var lastViewedAt: Date?
    var isCustom: Bool
    var estimatedMinutes: Int?
    var dueDate: Date?
    var urgency: TaskUrgency
    var order: Int?
    var timing: TaskTiming
    var priority: TaskPriority
    var guideSteps: [String]
    var tips: [String]
    var officialSourceURL: String?
    var officialSourceName: String?
    var content: TaskContent?
    var taskDetailContent: TaskDetailContent?
    var sourceTitle: String?
    var sourceURL: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        detail: String? = nil,
        isComplete: Bool = false,
        completedAt: Date? = nil,
        lastViewedAt: Date? = nil,
        isCustom: Bool = false,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        urgency: TaskUrgency = .medium,
        order: Int? = nil,
        timing: TaskTiming = .anytime,
        priority: TaskPriority = .shouldDo,
        guideSteps: [String] = [],
        tips: [String] = [],
        officialSourceURL: String? = nil,
        officialSourceName: String? = nil,
        content: TaskContent? = nil,
        taskDetailContent: TaskDetailContent? = nil,
        sourceTitle: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.lastViewedAt = lastViewedAt
        self.isCustom = isCustom
        self.estimatedMinutes = estimatedMinutes
        self.dueDate = dueDate
        self.urgency = urgency
        self.order = order
        self.timing = timing
        self.priority = priority
        self.guideSteps = guideSteps
        self.tips = tips
        self.officialSourceURL = officialSourceURL
        self.officialSourceName = officialSourceName
        self.content = content
        self.taskDetailContent = taskDetailContent
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case isComplete
        case completedAt
        case lastViewedAt
        case isCustom
        case estimatedMinutes
        case dueDate
        case urgency
        case order
        case timing
        case priority
        case guideSteps
        case tips
        case officialSourceURL
        case officialSourceName
        case content
        case taskDetailContent
        case cockpit
        case sourceTitle
        case sourceURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        self.isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.urgency = try container.decodeIfPresent(TaskUrgency.self, forKey: .urgency) ?? .medium
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.timing = try container.decodeIfPresent(TaskTiming.self, forKey: .timing) ?? .anytime
        self.priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .shouldDo
        self.guideSteps = try container.decodeIfPresent([String].self, forKey: .guideSteps) ?? []
        self.tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? []
        self.officialSourceURL = try container.decodeIfPresent(String.self, forKey: .officialSourceURL)
        self.officialSourceName = try container.decodeIfPresent(String.self, forKey: .officialSourceName)
        self.content = try container.decodeIfPresent(TaskContent.self, forKey: .content)
        self.taskDetailContent =
            (try? container.decodeIfPresent(TaskDetailContent.self, forKey: .taskDetailContent)) ??
            (try? container.decodeIfPresent(TaskDetailContent.self, forKey: .cockpit))
        self.sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
        self.sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(lastViewedAt, forKey: .lastViewedAt)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(urgency, forKey: .urgency)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encode(timing, forKey: .timing)
        try container.encode(priority, forKey: .priority)
        try container.encode(guideSteps, forKey: .guideSteps)
        try container.encode(tips, forKey: .tips)
        try container.encodeIfPresent(officialSourceURL, forKey: .officialSourceURL)
        try container.encodeIfPresent(officialSourceName, forKey: .officialSourceName)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(taskDetailContent, forKey: .taskDetailContent)
        try container.encodeIfPresent(sourceTitle, forKey: .sourceTitle)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
    }
}

struct ChecklistCategory: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var subtitle: String?
    var categoryType: String?
    var icon: String
    var gradient: [String]?
    var priority: Int?
    var priorityLevel: CategoryPriorityLevel?
    var urgency: CategoryUrgencyBand?
    var accentColorHex: String?
    var deadline: String?
    var isVisibleOverride: Bool?
    var order: Int?
    var cityFilters: [String]?
    var universityFilters: [String]?
    var unlockRequirements: String?
    var tasks: [ChecklistTask]

    var isVisible: Bool {
        isVisibleOverride ?? true
    }

    var visualPriority: CategoryPriorityLevel {
        if let priorityLevel {
            return priorityLevel
        }
        if let priority {
            return CategoryPriorityLevel.fromLegacy(priority: priority)
        }
        switch urgencyBand {
        case .immediate:
            return .critical
        case .week1:
            return .high
        case .week2:
            return .medium
        case .anytime, .completed:
            return .low
        }
    }

    var urgencyBand: CategoryUrgencyBand {
        if !tasks.isEmpty && tasks.allSatisfy(\.isComplete) {
            return .completed
        }
        if let urgency {
            return urgency
        }
        if tasks.contains(where: { $0.timing == .monthBeforeArrival || $0.timing == .weekBeforeArrival }) {
            return .immediate
        }
        if tasks.contains(where: { $0.timing == .firstWeek }) {
            return .week1
        }
        if tasks.contains(where: { $0.timing == .firstMonth }) {
            return .week2
        }
        if tasks.contains(where: { $0.priority == .mustDo }) {
            return .week1
        }
        return .anytime
    }

    var resolvedSubtitle: String {
        if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return subtitle
        }
        if let unlockRequirements, !unlockRequirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unlockRequirements
        }
        if tasks.isEmpty {
            return "No tasks available yet"
        }
        switch urgencyBand {
        case .immediate:
            return "Must complete before arrival"
        case .week1:
            return "Important for your first week"
        case .week2:
            return "Plan this in your first month"
        case .anytime:
            return "Complete when convenient"
        case .completed:
            return "All tasks completed"
        }
    }

    var deadlineLabel: String? {
        guard let deadline, !deadline.isEmpty else {
            return nil
        }
        if let date = Self.deadlineInputFormatter.date(from: deadline) ?? Self.fallbackDeadlineFormatter.date(from: deadline) {
            return Self.deadlineOutputFormatter.string(from: date)
        }
        return deadline
    }

    var deadlineDate: Date? {
        guard let deadline, !deadline.isEmpty else {
            return nil
        }
        return Self.deadlineInputFormatter.date(from: deadline) ?? Self.fallbackDeadlineFormatter.date(from: deadline)
    }

    func matchesAudience(city: String, university: String) -> Bool {
        let filters = AudienceFilters(
            cities: cityFilters ?? [],
            universities: universityFilters ?? []
        )
        return filters.matches(city: city, university: university)
    }

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        categoryType: String? = nil,
        icon: String,
        gradient: [String]? = nil,
        priority: Int? = nil,
        priorityLevel: CategoryPriorityLevel? = nil,
        urgency: CategoryUrgencyBand? = nil,
        accentColorHex: String? = nil,
        deadline: String? = nil,
        isVisibleOverride: Bool? = nil,
        order: Int? = nil,
        cityFilters: [String]? = nil,
        universityFilters: [String]? = nil,
        unlockRequirements: String? = nil,
        tasks: [ChecklistTask]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.categoryType = categoryType
        self.icon = icon
        self.gradient = gradient
        self.priority = priority
        self.priorityLevel = priorityLevel
        self.urgency = urgency
        self.accentColorHex = accentColorHex
        self.deadline = deadline
        self.isVisibleOverride = isVisibleOverride
        self.order = order
        self.cityFilters = cityFilters
        self.universityFilters = universityFilters
        self.unlockRequirements = unlockRequirements
        self.tasks = tasks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case type
        case categoryType
        case icon
        case gradient
        case priority
        case priorityLevel
        case visualPriority
        case urgency
        case accentColor
        case accentColorHex
        case deadline
        case isVisible
        case order
        case cityFilters
        case universityFilters
        case cities
        case universities
        case unlockRequirements
        case tasks
    }

    private static let deadlineInputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private static let fallbackDeadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let deadlineOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.id = decodedID.isEmpty ? UUID().uuidString : decodedID
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.categoryType =
            (try? container.decodeIfPresent(String.self, forKey: .type)) ??
            (try? container.decodeIfPresent(String.self, forKey: .categoryType))
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "square.grid.2x2"
        self.gradient = try container.decodeIfPresent([String].self, forKey: .gradient)

        if let numericPriority = try? container.decode(Int.self, forKey: .priority) {
            self.priority = numericPriority
            self.priorityLevel = nil
        } else if let rawPriority = try? container.decode(String.self, forKey: .priority),
                  let parsedPriority = CategoryPriorityLevel(rawValue: rawPriority.lowercased()) {
            self.priority = nil
            self.priorityLevel = parsedPriority
        } else if let explicitPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .priorityLevel) {
            self.priority = nil
            self.priorityLevel = explicitPriority
        } else if let visualPriority = try? container.decode(CategoryPriorityLevel.self, forKey: .visualPriority) {
            self.priority = nil
            self.priorityLevel = visualPriority
        } else {
            self.priority = nil
            self.priorityLevel = nil
        }

        self.urgency = try container.decodeIfPresent(CategoryUrgencyBand.self, forKey: .urgency)

        if let accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) {
            self.accentColorHex = accentColor
        } else {
            self.accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex)
        }

        self.deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        self.isVisibleOverride = try container.decodeIfPresent(Bool.self, forKey: .isVisible)
        self.order = try container.decodeIfPresent(Int.self, forKey: .order)
        self.cityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .cityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .cities))
        self.universityFilters =
            (try? container.decodeIfPresent([String].self, forKey: .universityFilters)) ??
            (try? container.decodeIfPresent([String].self, forKey: .universities))
        self.unlockRequirements = try container.decodeIfPresent(String.self, forKey: .unlockRequirements)
        self.tasks = try container.decodeIfPresent([ChecklistTask].self, forKey: .tasks) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(categoryType, forKey: .type)
        try container.encode(icon, forKey: .icon)
        try container.encodeIfPresent(gradient, forKey: .gradient)
        if let priorityLevel {
            try container.encode(priorityLevel.rawValue, forKey: .priority)
        } else {
            try container.encodeIfPresent(priority, forKey: .priority)
        }
        try container.encodeIfPresent(urgency, forKey: .urgency)
        try container.encodeIfPresent(accentColorHex, forKey: .accentColor)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encodeIfPresent(isVisibleOverride, forKey: .isVisible)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(cityFilters, forKey: .cityFilters)
        try container.encodeIfPresent(universityFilters, forKey: .universityFilters)
        try container.encodeIfPresent(unlockRequirements, forKey: .unlockRequirements)
        try container.encode(tasks, forKey: .tasks)
    }
}
