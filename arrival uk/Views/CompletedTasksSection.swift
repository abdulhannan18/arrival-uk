import SwiftUI

struct CompletedTasksSection: View {
    let tasks: [CategoryTask]
    let accentColor: Color

    @State private var isExpanded = false

    private var shouldCollapse: Bool {
        tasks.count > 3
    }

    var body: some View {
        if tasks.isEmpty {
            EmptyView()
        } else if shouldCollapse && !isExpanded {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isExpanded = true
                }
            } label: {
                Text("\(tasks.count) completed ✓")
                    .font(ArrivalTypography.figtree(size: 13, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.68))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ArrivalTokens.Spacing.lg)
        } else {
            ForEach(tasks) { task in
                TaskRowView(
                    task: .constant(task),
                    accentColor: accentColor,
                    dotColor: accentColor,
                    isFeatured: false,
                    onToggle: {},
                    onOpenGuide: {}
                )
            }
        }
    }
}
