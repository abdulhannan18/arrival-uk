import SwiftUI

struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.successMain)

            Text(message)
                .font(ArrivalTypography.figtree(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.spaceL)
        .padding(.vertical, Theme.spaceM)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: Theme.shadowSoft, radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }
}

struct ModalBackdrop: View {
    let onDismiss: () -> Void

    var body: some View {
        Rectangle()
            .fill(Theme.modalScrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss()
            }
    }
}

struct TaskMetaBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(ArrivalTypography.figtree(size: 11, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.track)
            )
    }
}

struct TaskMetaBadgeWrap: View {
    let labels: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                TaskMetaBadge(title: label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SourceMetadataLine: View {
    let source: SourceMetadata

    private var tone: Color {
        Theme.sourceTint(for: source.resolvedTrustType)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(source.resolvedTrustType.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tone)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(tone.opacity(0.12))
                )

            if let sourceName = source.sourceName, !sourceName.isEmpty {
                Text(sourceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let verifiedLabel = source.verifiedLabel {
                Text("Verified \(verifiedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct CheckMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? Theme.successMain : Theme.strokeStrong, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isOn ? Theme.successMain : Color.clear)
                )

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .opacity(isOn ? 1 : 0)
                .scaleEffect(isOn ? 1 : 0.6)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: isOn)
    }
}
