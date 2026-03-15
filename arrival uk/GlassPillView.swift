import SwiftUI

enum UrgencyLevel {
    case none
    case upcoming
    case overdue
}

struct GlassPillView: View {
    let text: String
    let urgencyLevel: UrgencyLevel

    private var borderColor: Color {
        switch urgencyLevel {
        case .overdue:
            return Color(hex: "D97706")
        case .upcoming:
            return .white.opacity(0.25)
        case .none:
            return .white.opacity(ArrivalTokens.GlassPill.borderOpacity)
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, ArrivalTokens.GlassPill.paddingH)
            .padding(.vertical, ArrivalTokens.GlassPill.paddingV)
            .background {
                RoundedRectangle(
                    cornerRadius: ArrivalTokens.GlassPill.cornerRadius,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: ArrivalTokens.GlassPill.cornerRadius,
                        style: .continuous
                    )
                    .fill(.white.opacity(ArrivalTokens.GlassPill.bgOpacity))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: ArrivalTokens.GlassPill.cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(borderColor, lineWidth: 1)
                }
            }
    }
}
