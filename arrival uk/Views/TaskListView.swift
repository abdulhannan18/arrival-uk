import SwiftUI

private struct TaskListScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TaskListView: View {
    @Binding var category: ChecklistCategory

    let accentColor: Color
    var dotColor: Color
    var showsScrollContainer: Bool = true
    var heroNamespace: Namespace.ID? = nil
    var selectedTaskID: String? = nil
    var onScroll: (CGFloat) -> Void
    var onTaskCompletionPersist: () -> Void
    var onCategoryComplete: () -> Void
    var onOpenGuide: (ChecklistTask) -> Void

    private var incompleteTaskIDs: [String] {
        category.tasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                let leftOrder = lhs.order ?? .max
                let rightOrder = rhs.order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    private var completedTaskIDs: [String] {
        category.tasks
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                let leftDate = lhs.completedAt ?? .distantPast
                let rightDate = rhs.completedAt ?? .distantPast
                if leftDate != rightDate {
                    return leftDate > rightDate
                }

                let leftOrder = lhs.order ?? .max
                let rightOrder = rhs.order ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    var body: some View {
        Group {
            if showsScrollContainer {
                ScrollView {
                    listContent
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: TaskListScrollOffsetKey.self,
                                    value: -proxy.frame(in: .named("task-list-scroll")).minY
                                )
                            }
                        )
                }
                .coordinateSpace(name: "task-list-scroll")
                .onPreferenceChange(TaskListScrollOffsetKey.self) { onScroll($0) }
                .drawingGroup(opaque: false)
            } else {
                listContent
            }
        }
    }

    private var listContent: some View {
        LazyVStack(spacing: 0) {
            if category.tasks.isEmpty {
                Text("Start with this one →")
                    .font(ArrivalTypography.figtree(size: 14, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .padding(.vertical, 24)
                    .padding(.horizontal, ArrivalTokens.Spacing.lg)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(incompleteTaskIDs.enumerated()), id: \.element) { index, taskID in
                if let taskBinding = taskBinding(for: taskID) {
                    TaskRowView(
                        task: taskBinding,
                        accentColor: accentColor,
                        dotColor: dotColor,
                        isFeatured: index == 0,
                        onToggle: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                toggleTask(taskID: taskID)
                            }
                        },
                        onOpenGuide: {
                            onOpenGuide(taskBinding.wrappedValue)
                        },
                        heroNamespace: heroNamespace,
                        isHiddenForHero: selectedTaskID == taskID
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.92).combined(with: .opacity)
                        )
                    )
                }
            }

            if !completedTaskIDs.isEmpty {
                Text("Completed")
                    .font(ArrivalTypography.figtree(size: 8.5, weight: .bold))
                    .tracking(1.87)
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .textCase(.uppercase)
                    .padding(.horizontal, ArrivalTokens.Spacing.lg)
                    .padding(.top, 26)
                    .padding(.bottom, 8)

                ForEach(completedTaskIDs, id: \.self) { taskID in
                    if let taskBinding = taskBinding(for: taskID) {
                        TaskRowView(
                            task: taskBinding,
                            accentColor: accentColor,
                            dotColor: dotColor,
                            isFeatured: false,
                            onToggle: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    toggleTask(taskID: taskID)
                                }
                            },
                            onOpenGuide: {
                                onOpenGuide(taskBinding.wrappedValue)
                            },
                            heroNamespace: heroNamespace
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: incompleteTaskIDs)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: completedTaskIDs)
    }

    private func taskBinding(for taskID: String) -> Binding<ChecklistTask>? {
        guard let index = category.tasks.firstIndex(where: { $0.id == taskID }) else {
            return nil
        }
        return $category.tasks[index]
    }

    private func toggleTask(taskID: String) {
        guard let index = category.tasks.firstIndex(where: { $0.id == taskID }) else {
            return
        }

        let wasCompleted = category.tasks[index].isCompleted
        category.tasks[index].isCompleted.toggle()
        category.tasks[index].completedAt = category.tasks[index].isCompleted ? Date() : nil

        if !wasCompleted && category.tasks[index].isCompleted {
            StreakManager.shared.recordTaskCompletion()
        }

        onTaskCompletionPersist()

        if !wasCompleted && category.tasks.allSatisfy(\.isCompleted) {
            onCategoryComplete()
        }
    }
}
