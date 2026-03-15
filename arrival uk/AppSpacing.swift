import SwiftUI

// MARK: - 8-Point Grid System
extension CGFloat {
    /// 4px - Micro-adjustments (e.g., icon to text)
    static let spaceXs: CGFloat = 4
    /// 8px - Tight grouping (e.g., title to subtitle)
    static let spaceSm: CGFloat = 8
    /// 16px - Standard container padding & screen margins
    static let spaceMd: CGFloat = 16
    /// 24px - Section breaks
    static let spaceLg: CGFloat = 24
    /// 32px - Major structural breaks
    static let spaceXl: CGFloat = 32
    /// 40px - Bottom navigation clearance
    static let spaceXxl: CGFloat = 40
}

enum AppTheme {}

extension AppTheme {
    enum Spacing {
        static let xs = CGFloat.spaceXs
        static let sm = CGFloat.spaceSm
        static let md = CGFloat.spaceMd
        static let lg = CGFloat.spaceLg
        static let xl = CGFloat.spaceXl
        static let xxl = CGFloat.spaceXxl
    }

    enum Layout {
        static let minimumTouchTarget: CGFloat = 44
        static let actionIconSize: CGFloat = 18
        static let actionShadowRadius: CGFloat = 8
        static let actionShadowYOffset: CGFloat = 2
        static let greetingScaleFloor: CGFloat = 0.75
        static let statusScaleFloor: CGFloat = 0.85

        static let heroCardCornerRadius: CGFloat = 28
        static let heroCardShadowOpacity: CGFloat = 0.12
        static let heroCardShadowRadius: CGFloat = 20
        static let heroCardShadowYOffset: CGFloat = 12
        static let heroCardMinHeight: CGFloat = 220
        static let heroInternalPadding: CGFloat = CGFloat.spaceLg
        static let heroPeekScale: CGFloat = 0.95
        static let heroPeekYOffset: CGFloat = 12
        static let heroPeekOpacity: CGFloat = 0.40
        static let heroPeekBlurRadius: CGFloat = 1
        static let heroSwipeCommitThreshold: CGFloat = 150
        static let heroDismissTravelDistance: CGFloat = 480
        static let heroRotationDivisor: CGFloat = 15
        static let heroVerticalDragFactor: CGFloat = 0.30
        static let heroPopDelayNanos: UInt64 = 80_000_000
        static let maintenanceIconSize: CGFloat = 24
        static let maintenanceRowCornerRadius: CGFloat = 14

        static let walletCardAspectRatio: CGFloat = 1.586
        static let walletFanRotationDelta: Double = 12
        static let walletFanOffset: CGFloat = 45
        static let walletCardMaxWidth: CGFloat = 320
        static let walletCardShadowRadius: CGFloat = 15
        static let walletCardShadowYOffset: CGFloat = 10
        static let walletCardCornerRadius: CGFloat = 22
        static let walletCollapsedStackHeight: CGFloat = 214
        static let walletExpandedStackHeight: CGFloat = 254
        static let walletPrivacyBlurRadius: CGFloat = 20

        static let smartGuideDismissTranslationThreshold: CGFloat = 100
        static let smartGuideDismissProjectedVelocityThreshold: CGFloat = 200
        static let smartGuideDismissSpringResponse: CGFloat = 0.45
        static let smartGuideDismissSpringDamping: CGFloat = 0.8

        static let discoveryPivotCornerRadius: CGFloat = 24
        static let discoveryTileCornerRadius: CGFloat = 20
        static let discoveryTileMinHeight: CGFloat = 120
        static let discoveryLockedPreviewBlur: CGFloat = 6
        static let discoveryCardSize: CGFloat = 160
        static let discoveryCardImageHeight: CGFloat = 100
        static let discoveryShimmerTravel: CGFloat = 180
        static let discoveryShimmerDuration: TimeInterval = 1.1

        static let confettiBirthRate: Float = 26
        static let confettiLifetime: Float = 4
        static let confettiVelocity: CGFloat = 220
        static let confettiScale: CGFloat = 0.12
        static let confettiEmissionRange: CGFloat = .pi
        static let confettiStopDelay: TimeInterval = 3.0
        static let confettiCleanupDelay: TimeInterval = 3.8
    }
}
