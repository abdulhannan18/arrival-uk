import SwiftUI
import UIKit

enum FigtreeWeight {
    case regular
    case medium
    case semibold
    case bold
    case extraBold
    case black

    fileprivate var postScriptName: String {
        switch self {
        case .regular:
            return "Figtree-Regular"
        case .medium:
            return "Figtree-Medium"
        case .semibold:
            return "Figtree-SemiBold"
        case .bold:
            return "Figtree-Bold"
        case .extraBold:
            return "Figtree-ExtraBold"
        case .black:
            return "Figtree-Black"
        }
    }

    fileprivate var fallbackWeight: Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .extraBold:
            return .heavy
        case .black:
            return .black
        }
    }
}

enum ArrivalTypography {
    static func figtree(size: CGFloat, weight: FigtreeWeight) -> Font {
        if UIFont(name: weight.postScriptName, size: size) != nil {
            return .custom(weight.postScriptName, size: size)
        }
        return .system(size: size, weight: weight.fallbackWeight, design: .default)
    }

    static func cardTitle(for title: String) -> Font {
        let size: CGFloat
        switch title.count {
        case ..<12:
            size = 24
        case 12..<18:
            size = 22
        case 18..<24:
            size = 20
        default:
            size = 18
        }

        return figtree(size: size, weight: .black)
    }

    static func taskTitle(featured: Bool) -> Font {
        featured
            ? figtree(size: 16, weight: .semibold)
            : figtree(size: 14, weight: .medium)
    }

    static func progressStatement(completed: Int, total: Int) -> String {
        guard total > 0 else {
            return "Let's get started"
        }

        let ratio = Double(completed) / Double(total)
        switch ratio {
        case 0:
            return "Let's get started"
        case ..<0.33:
            return "Good start — keep going"
        case ..<0.66:
            return "You're making real progress"
        case ..<1.0:
            return "Almost there"
        default:
            return "All done here ✓"
        }
    }

    static func taskCount(completed: Int, total: Int) -> String {
        if completed == total, total > 0 {
            return "Complete ✓"
        }
        return "\(completed) of \(total) tasks"
    }
}
