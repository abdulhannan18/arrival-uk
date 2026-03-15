import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class MarketplaceAnalyticsStore {
    static let shared = MarketplaceAnalyticsStore()

    private let storageKey = "marketplace.analytics.funnel.v1"

    struct FunnelStats: Codable, Hashable {
        var startedByEntryPoint: [String: Int]
        var completedByEntryPoint: [String: Int]
    }

    private(set) var stats: FunnelStats

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FunnelStats.self, from: data) {
            stats = decoded
        } else {
            stats = FunnelStats(startedByEntryPoint: [:], completedByEntryPoint: [:])
        }
    }

    func recordStarted(providerID: String, entryPoint: String) {
        let key = normalizedEntryPoint(entryPoint)
        stats.startedByEntryPoint[key, default: 0] += 1
        persist()

        TelemetryStore.shared.record(
            name: "marketplace_funnel_started",
            level: .info,
            properties: [
                "providerID": providerID,
                "entryPoint": key,
                "startedCount": "\(stats.startedByEntryPoint[key] ?? 0)"
            ]
        )
    }

    func recordCompleted(providerID: String, entryPoint: String, completionToken: String) {
        let key = normalizedEntryPoint(entryPoint)
        stats.completedByEntryPoint[key, default: 0] += 1
        persist()

        let completionDigest = SHA256.hash(data: Data(completionToken.utf8))
        let anonymizedToken = Data(completionDigest).base64EncodedString().prefix(16)
        TelemetryStore.shared.record(
            name: "marketplace_funnel_completed",
            level: .info,
            properties: [
                "providerID": providerID,
                "entryPoint": key,
                "completionTokenDigest": String(anonymizedToken),
                "completedCount": "\(stats.completedByEntryPoint[key] ?? 0)"
            ]
        )
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    private func normalizedEntryPoint(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "unknown" : trimmed
    }
}
