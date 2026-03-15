import Foundation

enum CollaborativeTaskStatus: String, Codable, Hashable {
    case pending
    case completed
}

struct LamportTimestamp: Codable, Hashable, Comparable {
    let counter: Int64
    let actorID: String

    static func < (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        if lhs.counter != rhs.counter {
            return lhs.counter < rhs.counter
        }
        return lhs.actorID < rhs.actorID
    }
}

struct CollaborativeTaskRecord: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var categoryID: String
    var status: CollaborativeTaskStatus
    var isTier1Urgent: Bool
    var lastEditedBy: String
    var timestamp: LamportTimestamp
    var completedAtMillis: Int64?
}

struct CollaborativeTaskLWWSet: Codable, Hashable {
    private(set) var entriesByID: [String: CollaborativeTaskRecord] = [:]
    private(set) var tombstonesByID: [String: LamportTimestamp] = [:]

    mutating func upsert(_ entry: CollaborativeTaskRecord) {
        let trimmedID = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        if let tombstone = tombstonesByID[trimmedID], entry.timestamp <= tombstone {
            return
        }

        if let existing = entriesByID[trimmedID], existing.timestamp > entry.timestamp {
            return
        }

        var sanitized = entry
        sanitized.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.categoryID = entry.categoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        entriesByID[trimmedID] = sanitized
    }

    mutating func remove(taskID: String, tombstone: LamportTimestamp) {
        let trimmedID = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }

        if let existingTombstone = tombstonesByID[trimmedID], existingTombstone > tombstone {
            return
        }

        tombstonesByID[trimmedID] = tombstone
        if let existing = entriesByID[trimmedID], existing.timestamp <= tombstone {
            entriesByID.removeValue(forKey: trimmedID)
        }
    }

    mutating func merge(with remote: CollaborativeTaskLWWSet) {
        for (taskID, tombstone) in remote.tombstonesByID {
            remove(taskID: taskID, tombstone: tombstone)
        }

        for entry in remote.entriesByID.values {
            upsert(entry)
        }

        for (taskID, tombstone) in tombstonesByID {
            if let localEntry = entriesByID[taskID], localEntry.timestamp <= tombstone {
                entriesByID.removeValue(forKey: taskID)
            }
        }
    }

    var resolvedEntries: [CollaborativeTaskRecord] {
        entriesByID.values
            .filter { entry in
                guard let tombstone = tombstonesByID[entry.id] else { return true }
                return entry.timestamp > tombstone
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp > rhs.timestamp
                }
                return lhs.id < rhs.id
            }
    }
}
