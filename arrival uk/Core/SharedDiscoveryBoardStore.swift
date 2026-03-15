import Foundation
import Observation

struct SharedDiscoveryBoardItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let addedBy: String
    let addedAt: Date
}

@MainActor
@Observable
final class SharedDiscoveryBoardStore {
    static let shared = SharedDiscoveryBoardStore()

    private let storageKey = StorageKey.sharedDiscoveryBoard.rawValue
    private let maxItems = 24

    var items: [SharedDiscoveryBoardItem] = []

    private init() {
        load()
    }

    func addItem(
        id: String,
        title: String,
        subtitle: String,
        symbolName: String,
        addedBy: String
    ) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return }

        let entry = SharedDiscoveryBoardItem(
            id: normalizedID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            addedBy: addedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You" : addedBy,
            addedAt: .now
        )

        items.removeAll(where: { $0.id == normalizedID })
        items.insert(entry, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SharedDiscoveryBoardItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
