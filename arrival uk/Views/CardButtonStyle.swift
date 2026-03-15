import SwiftUI

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .animation(
                configuration.isPressed
                    ? .timingCurve(0.16, 1, 0.3, 1, duration: 0.24)
                    : .timingCurve(0.16, 1, 0.3, 1, duration: 0.34),
                value: configuration.isPressed
            )
    }
}
