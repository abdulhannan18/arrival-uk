import CoreML
import Foundation

struct TaskUrgencyContext {
    let daysSinceArrival: Int
    let completedTaskCount: Int
    let totalTaskCount: Int
    let university: String
    let city: String

    var completionRatio: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    static func liveContext(
        categories: [ChecklistCategory],
        arrivalDate: Date,
        university: String,
        city: String,
        now: Date = .now
    ) -> TaskUrgencyContext {
        let totalTaskCount = categories.reduce(0) { partial, category in
            partial + category.tasks.count
        }
        let completedTaskCount = categories.reduce(0) { partial, category in
            partial + category.tasks.reduce(0) { taskPartial, task in
                taskPartial + (task.isComplete ? 1 : 0)
            }
        }

        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfArrival = calendar.startOfDay(for: arrivalDate)
        let daysSinceArrival = calendar.dateComponents([.day], from: startOfArrival, to: startOfNow).day ?? 0

        return TaskUrgencyContext(
            daysSinceArrival: daysSinceArrival,
            completedTaskCount: completedTaskCount,
            totalTaskCount: totalTaskCount,
            university: university,
            city: city
        )
    }
}

final class TaskUrgencyPredictor {
    static let shared = TaskUrgencyPredictor()

    private static let maxRecommendedModelBytes: Int64 = 5_000_000

    private var cachedModel: MLModel?
    private var attemptedModelLoad = false

    private init() {}

    func predictUrgencyScore(for task: AppTask, context: TaskUrgencyContext) -> Double {
        if let modelScore = predictWithModel(task: task, context: context) {
            return Self.clamped(modelScore)
        }
        return heuristicScore(task: task, context: context)
    }

    private func predictWithModel(task: AppTask, context: TaskUrgencyContext) -> Double? {
        guard let model = loadModelIfAvailable() else { return nil }

        let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "DaysSinceArrival": MLFeatureValue(int64: Int64(context.daysSinceArrival)),
            "TasksCompleted": MLFeatureValue(int64: Int64(context.completedTaskCount)),
            "TasksTotal": MLFeatureValue(int64: Int64(context.totalTaskCount)),
            "UniversityType": MLFeatureValue(string: universityType(for: context.university)),
            "Location": MLFeatureValue(string: locationType(for: context.city)),
            "TaskPriority": MLFeatureValue(string: task.priority.rawValue),
            "TaskTiming": MLFeatureValue(string: task.timing.rawValue)
        ])
        guard let provider else { return nil }

        do {
            let output = try model.prediction(from: provider)
            if let namedScore = output.featureValue(for: "UrgencyScore")?.doubleValue ??
                output.featureValue(for: "urgencyScore")?.doubleValue {
                return namedScore
            }

            for key in output.featureNames {
                if let value = output.featureValue(for: key)?.doubleValue {
                    return value
                }
            }
        } catch {
            CrashReporter.record(error: error, context: "task_urgency_model_predict")
        }

        return nil
    }

    private func loadModelIfAvailable() -> MLModel? {
        if attemptedModelLoad {
            return cachedModel
        }
        attemptedModelLoad = true

        guard let modelURL = Bundle.main.url(forResource: "TaskUrgencyRegressor", withExtension: "mlmodelc") else {
            return nil
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
           let fileSize = attributes[.size] as? NSNumber,
           fileSize.int64Value > Self.maxRecommendedModelBytes {
            TelemetryStore.shared.record(
                name: "phase10_model_size_warning",
                level: .warning,
                properties: [
                    "model": "TaskUrgencyRegressor",
                    "bytes": "\(fileSize.int64Value)"
                ]
            )
            return nil
        }

        do {
            let model = try MLModel(contentsOf: modelURL)
            cachedModel = model
            return model
        } catch {
            CrashReporter.record(error: error, context: "task_urgency_model_load")
            return nil
        }
    }

    private func heuristicScore(task: AppTask, context: TaskUrgencyContext) -> Double {
        var score = 0.36
        let completionRatio = context.completionRatio

        switch task.priority {
        case .mustDo:
            score += 0.23
        case .shouldDo:
            score += 0.12
        case .optional:
            score += 0.02
        }

        switch task.urgency {
        case .high:
            score += 0.18
        case .medium:
            score += 0.09
        case .low:
            score += 0.02
        }

        switch task.timing {
        case .monthBeforeArrival, .weekBeforeArrival:
            score += context.daysSinceArrival > 0 ? 0.09 : 0.14
        case .firstWeek:
            score += context.daysSinceArrival <= 7 ? 0.15 : 0.08
        case .firstMonth:
            score += context.daysSinceArrival <= 30 ? 0.11 : 0.05
        case .ongoing:
            score += 0.05
        case .anytime:
            score += 0.03
        }

        if completionRatio < 0.35 {
            score += 0.11
        } else if completionRatio < 0.60 {
            score += 0.06
        }

        if isBankingTask(task) && context.daysSinceArrival > 10 && completionRatio < 0.70 {
            score += 0.12
        }

        if highPressureUniversities.contains(normalize(context.university)) {
            score += 0.04
        }

        if highCostCities.contains(normalize(context.city)) {
            score += 0.03
        }

        if let dueDate = task.dueDate {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: .now, to: dueDate).day ?? 0
            if daysUntilDue <= 1 {
                score += 0.20
            } else if daysUntilDue <= 3 {
                score += 0.12
            } else if daysUntilDue <= 7 {
                score += 0.06
            }
        }

        return Self.clamped(score)
    }

    private func universityType(for university: String) -> String {
        highPressureUniversities.contains(normalize(university)) ? "high_pressure" : "standard"
    }

    private func locationType(for city: String) -> String {
        highCostCities.contains(normalize(city)) ? "high_cost_urban" : "standard"
    }

    private func isBankingTask(_ task: AppTask) -> Bool {
        let normalizedTitle = normalize(task.title)
        let normalizedCategory = normalize(task.categoryTitle)
        return normalizedTitle.contains("bank") ||
            normalizedTitle.contains("account") ||
            normalizedCategory.contains("bank") ||
            normalizedCategory.contains("money")
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func clamped(_ score: Double) -> Double {
        min(max(score, 0), 1)
    }

    private let highPressureUniversities: Set<String> = [
        "university of oxford",
        "university of cambridge",
        "imperial college london",
        "ucl",
        "king's college london",
        "london school of economics and political science"
    ]
    private let highCostCities: Set<String> = [
        "london",
        "oxford",
        "cambridge",
        "edinburgh"
    ]
}
