import SwiftUI

extension Color {
    enum App {
        // Backgrounds
        static let bgPrimary = Color("bgPrimary")
        static let bgSurface = Color("bgSurface")

        // Text
        static let textPrimary = Color("textPrimary")
        static let textSecondary = Color("textSecondary")

        // Actions & Status
        static let actionPrimary = Color("actionPrimary")
        static let statusUrgent = Color("statusUrgent")
    }
}

extension AppTheme {
    enum Colors {
        static let bgPrimary = Color.App.bgPrimary
        static let bgSurface = Color.App.bgSurface
        static let textPrimary = Color.App.textPrimary
        static let textSecondary = Color.App.textSecondary
        static let actionPrimary = Color.App.actionPrimary
        static let statusUrgent = Color.App.statusUrgent
    }
}
