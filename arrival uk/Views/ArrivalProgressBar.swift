import SwiftUI

struct ArrivalProgressBar: View {
    let value: Double
    let color: Color
    let completed: Int
    let total: Int
    var statementColor: Color = .secondary

    @State private var shimmerOffset: CGFloat = -80

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var markerCount: Int {
        max(total, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArrivalTokens.Spacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(
                        cornerRadius: ArrivalTokens.Progress.cornerRadius,
                        style: .continuous
                    )
                    .fill(color.opacity(ArrivalTokens.Progress.trackOpacity))
                    .frame(height: ArrivalTokens.Progress.height)

                    HStack(spacing: 0) {
                        ForEach(0..<markerCount, id: \.self) { index in
                            Group {
                                if index >= completed {
                                    Circle()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(width: 4, height: 4)
                                } else {
                                    Color.clear
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: geometry.size.width / CGFloat(markerCount), alignment: .center)
                        }
                    }

                    RoundedRectangle(
                        cornerRadius: ArrivalTokens.Progress.cornerRadius,
                        style: .continuous
                    )
                    .fill(color)
                    .frame(
                        width: max(0, geometry.size.width * clampedValue),
                        height: ArrivalTokens.Progress.height
                    )
                    .shadow(
                        color: color.opacity(ArrivalTokens.Progress.glowOpacity * clampedValue + 0.2),
                        radius: ArrivalTokens.Progress.glowRadius
                    )
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.26), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40)
                            .offset(x: shimmerOffset)
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ArrivalTokens.Progress.cornerRadius,
                            style: .continuous
                        )
                    )
                }
            }
            .frame(height: ArrivalTokens.Progress.height)

            Text(
                ArrivalTypography.progressStatement(
                    completed: completed,
                    total: total
                )
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(statementColor)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 420
            }
        }
    }
}
