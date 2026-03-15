import Foundation
import SwiftUI
import UIKit

@MainActor
final class DiscoveryImageCache {
    enum CacheTier: String {
        case tier1Critical
        case tier2Standard
        case tier3Disposable
    }

    enum PurgePolicy: String {
        case all
        case tier3Only
    }

    static let shared = DiscoveryImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private var memoryWarningObserver: NSObjectProtocol?
    private var cacheTierByKey: [NSURL: CacheTier] = [:]

    private init() {
        cache.countLimit = 120
        cache.totalCostLimit = 40 * 1024 * 1024

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.purge(reason: "memory_warning", policy: .tier3Only)
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL, tier: CacheTier = .tier3Disposable) {
        let key = url as NSURL
        let estimatedBytes = Int(image.size.width * image.size.height * image.scale * image.scale) * 4
        cache.setObject(image, forKey: key, cost: estimatedBytes)
        cacheTierByKey[key] = tier
    }

    func purge(reason: String, policy: PurgePolicy = .all) {
        let removedCount: Int
        switch policy {
        case .all:
            removedCount = cacheTierByKey.count
            cache.removeAllObjects()
            cacheTierByKey.removeAll()
        case .tier3Only:
            removedCount = purgeTier3Entries()
        }

        TelemetryStore.shared.record(
            name: "discovery_image_cache_purged",
            level: .warning,
            properties: [
                "reason": reason,
                "policy": policy.rawValue,
                "removedEntries": "\(removedCount)"
            ]
        )
    }

    private func purgeTier3Entries() -> Int {
        let disposableKeys = cacheTierByKey.compactMap { key, tier in
            tier == .tier3Disposable ? key : nil
        }

        for key in disposableKeys {
            cache.removeObject(forKey: key)
            cacheTierByKey.removeValue(forKey: key)
        }
        return disposableKeys.count
    }
}
