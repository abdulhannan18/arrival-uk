import SwiftUI

struct PremiumIcon: View {
    let systemName: String
    let primary: Color
    var size: CGFloat = 56

    private var cornerRadius: CGFloat {
        max(12, size * 0.285)
    }

    private var glyphSize: CGFloat {
        max(18, size * 0.52)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.75), primary.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

            Image(systemName: systemName)
                .font(.system(size: glyphSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(primary, primary.opacity(0.45))
                .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
