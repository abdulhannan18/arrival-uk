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
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(categoryColor.opacity(0.14))

                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(HomeLocalization.todayCardLabel)
                        .font(ArrivalTypography.figtree(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.secondaryText)

                    Text(task.title)
                        .font(ArrivalTypography.figtree(size: 17, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)

                    Text(category.title)
                        .font(ArrivalTypography.figtree(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(estimatedMinutesText)
                        .font(ArrivalTypography.figtree(size: 13, weight: .semibold))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(categoryColor.opacity(0.12), in: Capsule(style: .continuous))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Theme.shadowMedium, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(task.title)
        .accessibilityHint(HomeLocalization.categoryCardHint)
    }
}
