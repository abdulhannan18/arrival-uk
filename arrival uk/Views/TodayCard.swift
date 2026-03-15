import SwiftUI

struct TodayCard: View {
    let task: ChecklistTask
    let category: ChecklistCategory
    let onTap: () -> Void

    private var categoryColor: Color {
        return CategoryColorSystem.color(for: category, index: 0).color
    }

    private var estimatedMinutesText: String {
        let fallback = max(5, category.estimatedMinutes)
        return HomeLocalization.todayEstimatedMinutes(task.estimatedMinutes ?? fallback)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(HomeLocalization.todayCardLabel)
                        .font(ArrivalTypography.figtree(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(task.title)
                        .font(ArrivalTypography.figtree(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Text(estimatedMinutesText)
                    .font(ArrivalTypography.figtree(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule(style: .continuous))
            }
            .padding(18)
            .background(categoryColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(task.title)
        .accessibilityHint(HomeLocalization.categoryCardHint)
    }
}
