import SwiftUI

@available(iOS 17.0, *)
struct TaskSearchResult: Identifiable, Hashable {
    let id: String
    let categoryID: String
    let categoryTitle: String
    let task: ChecklistTask

    init(categoryID: String, categoryTitle: String, task: ChecklistTask) {
        self.id = "\(categoryID)::\(task.id)"
        self.categoryID = categoryID
        self.categoryTitle = categoryTitle
        self.task = task
    }
}

@available(iOS 17.0, *)
struct TaskSearchSheet: View {
    let categories: [ChecklistCategory]
    let city: String
    let university: String
    var onSelectTask: (TaskSearchResult) -> Void
    var onClose: (() -> Void)? = nil

    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var results: [TaskSearchResult] {
        let visibleCategories = categories.filter {
            $0.isVisible && !$0.tasks.isEmpty && $0.matchesAudience(city: city, university: university)
        }

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else { return [] }

        return visibleCategories.flatMap { category in
            category.tasks.compactMap { task in
                let haystack: [String] = [
                    task.title,
                    task.detail ?? "",
                    task.sourceTitle ?? ""
                ]
                .map { $0.lowercased() }

                guard haystack.contains(where: { $0.contains(normalizedQuery) }) else {
                    return nil
                }

                return TaskSearchResult(
                    categoryID: category.id,
                    categoryTitle: category.title,
                    task: task
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.spaceS) {
                Text("Search Tasks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Button("Done") { close() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.linkText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .padding(.bottom, Theme.spaceS)

            Divider()
                .overlay(Theme.stroke)

            VStack(spacing: Theme.spaceM) {
                HStack(spacing: Theme.spaceS) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.tertiaryText)
                    TextField("Search by task, details, source…", text: $query)
                        .focused($isSearchFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clears the search query")
                    }
                }
                .padding(.horizontal, Theme.spaceM)
                .padding(.vertical, Theme.spaceS)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(Theme.gray50)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    placeholder(
                        icon: "magnifyingglass",
                        title: "Search for a task",
                        message: "Type any keyword like visa, GP, railcard, bank, or council tax."
                    )
                } else if results.isEmpty {
                    placeholder(
                        icon: "exclamationmark.magnifyingglass",
                        title: "No results",
                        message: "Try a broader keyword."
                    )
                } else {
                    List(results) { result in
                        Button {
                            onSelectTask(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.task.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.primaryText)
                                Text(result.categoryTitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                if let detail = result.task.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Theme.tertiaryText)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.card)
                }
            }
            .padding(.horizontal, Theme.spaceXL)
            .padding(.top, Theme.spaceM)
            .background(Theme.card)
        }
        .background(Theme.card)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isSearchFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Theme.spaceS) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Theme.spaceXL)
    }

    private func close() {
        onClose?()
    }
}
