import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct ArrivalActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStep: String
        var progress: Double
        var documentSymbol: String
    }

    var taskTitle: String
}
