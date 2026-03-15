import SwiftUI

enum ArrivalTokens {

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Card {
        static let cornerRadius: CGFloat = 20
        static let height: CGFloat = 160
        static let horizontalPad: CGFloat = 18
        static let verticalGap: CGFloat = 11
        static let innerPadding: CGFloat = 16
        static let symbolOpacity: Double = 0.07
        static let symbolSize: CGFloat = 42
        static let symbolOffsetX: CGFloat = 13
        static let symbolOffsetY: CGFloat = 13
        static let shadowOpacity: Double = 0.45
        static let shadowRadius: CGFloat = 20
        static let shadowY: CGFloat = 8
        static let pressScale: Double = 0.97
        static let peekHeight: CGFloat = 40
        static let sheenHeight: CGFloat = 3
    }

    enum GlassPill {
        static let blurRadius: CGFloat = 12
        static let bgOpacity: Double = 0.15
        static let borderOpacity: Double = 0.20
        static let cornerRadius: CGFloat = 20
        static let paddingH: CGFloat = 12
        static let paddingV: CGFloat = 5
    }

    enum Animation {
        static let cardStagger: Double = 0.04
        static let tapRippleDur: Double = 0.12
        static let tapFlashDur: Double = 0.08
        static let openTransition: Double = 0.32
        static let springResponse: Double = 0.40
        static let springDamping: Double = 0.82
        static let taskComplete: Double = 0.20
        static let taskSettle: Double = 0.18
        static let progressFill: Double = 0.40
        static let completionCelebr: Double = 0.60
    }

    enum Task {
        static let featuredPaddingV: CGFloat = 20
        static let normalPaddingV: CGFloat = 12
        static let completedPaddingV: CGFloat = 8
        static let accentBorderW: CGFloat = 3
        static let completedOpacity: Double = 0.65
        static let cornerRadius: CGFloat = 14
        static let gapBetween: CGFloat = 8
        static let sectionDividerOp: Double = 0.08
    }

    enum Progress {
        static let height: CGFloat = 8
        static let cornerRadius: CGFloat = 4
        static let trackOpacity: Double = 0.12
        static let glowOpacity: Double = 0.60
        static let glowRadius: CGFloat = 6
    }

    enum DetailHeader {
        static let fullHeight: CGFloat = 230
        static let collapsedHeight: CGFloat = 64
        static let symbolOpacity: Double = 0.15
        static let contentTintOp: Double = 0.04
        static let collapseAt: CGFloat = 80
    }
}
