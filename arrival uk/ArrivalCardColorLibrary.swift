import SwiftUI

// Legacy compatibility wrapper.
// Source of truth is ArrivalColor in CategoryColorSystem.swift.
enum ArrivalCardColorLibrary {
    struct Entry: Hashable {
        let assetName: String
        let hex: String

        var color: Color {
            Color(hex: hex)
        }
    }

    static let all: [Entry] = CategoryFamily.allCases.flatMap { family in
        (1 ... 15).map { tone in
            Entry(
                assetName: "arrival_\(family.rawValue)_t\(tone)",
                hex: ArrivalColor.hex(family: family, toneIndex: tone)
            )
        }
    }
}
