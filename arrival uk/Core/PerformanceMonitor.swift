import Foundation
import MetricKit
import OSLog
import SwiftUI
import os.signpost

@MainActor
final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    private struct SwipeTrace {
        let startedAt: Date
        let signpostID: OSSignpostID
        var frameSamples: Int
        var maxHorizontalTravel: CGFloat
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "PhysicsEngine"
    )
    private let signpostLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "PhysicsEngineTrace"
    )
    private let minimumHealthyFPS = 55.0
    private let hitchRatioWarningThreshold = 0.08
    private var hasBootstrapped = false
    private var activeSwipe: SwipeTrace?

    private override init() {
        super.init()
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        MXMetricManager.shared.add(self)

        TelemetryStore.shared.record(
            name: "physics_monitor_bootstrapped",
            level: .info
        )
    }

    func beginHeroSwipeIfNeeded() {
        guard activeSwipe == nil else { return }
        let signpostID = OSSignpostID(log: signpostLog)
        activeSwipe = SwipeTrace(
            startedAt: Date(),
            signpostID: signpostID,
            frameSamples: 0,
            maxHorizontalTravel: .zero
        )
        os_signpost(.begin, log: signpostLog, name: "HeroSwipe", signpostID: signpostID)
    }

    func recordHeroSwipeFrame(translation: CGSize) {
        beginHeroSwipeIfNeeded()
        guard var trace = activeSwipe else { return }
        trace.frameSamples += 1
        trace.maxHorizontalTravel = max(trace.maxHorizontalTravel, abs(translation.width))
        activeSwipe = trace
    }

    func endHeroSwipe(didCommit: Bool) {
        guard let trace = activeSwipe else { return }
        activeSwipe = nil

        let elapsed = max(Date().timeIntervalSince(trace.startedAt), 0.001)
        let estimatedFPS = Double(trace.frameSamples) / elapsed

        os_signpost(
            .end,
            log: signpostLog,
            name: "HeroSwipe",
            signpostID: trace.signpostID,
            "commit=%{public}d fps=%{public}.2f maxTravel=%{public}.2f samples=%{public}d",
            didCommit ? 1 : 0,
            estimatedFPS,
            trace.maxHorizontalTravel,
            trace.frameSamples
        )

        let level: CrashLogLevel = estimatedFPS < minimumHealthyFPS ? .warning : .info
        let properties = [
            "didCommit": didCommit ? "1" : "0",
            "estimatedFPS": String(format: "%.2f", estimatedFPS),
            "durationMs": String(format: "%.0f", elapsed * 1000),
            "maxHorizontalTravel": String(format: "%.1f", trace.maxHorizontalTravel),
            "frameSamples": "\(trace.frameSamples)"
        ]
        TelemetryStore.shared.record(
            name: "phase3_hero_swipe_trace",
            level: level,
            properties: properties
        )

        if estimatedFPS < minimumHealthyFPS {
            logger.warning(
                "hero swipe hitch risk fps=\(estimatedFPS, format: .fixed(precision: 2)) duration=\(elapsed, format: .fixed(precision: 3))"
            )
            CrashReporter.log(
                "hero_swipe_low_fps fps=\(String(format: "%.2f", estimatedFPS))",
                level: .warning
            )
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let payloadCount = payloads.count
        guard payloadCount > 0 else { return }

        Task { @MainActor in
            for payload in payloads {
                guard let hitchRatio = payload.animationMetrics?.scrollHitchTimeRatio.value else {
                    continue
                }
                if hitchRatio >= hitchRatioWarningThreshold {
                    logger.warning(
                        "MetricKit hitch ratio high: \(hitchRatio, format: .fixed(precision: 4))"
                    )
                    TelemetryStore.shared.record(
                        name: "phase3_hitch_ratio_warning",
                        level: .warning,
                        properties: [
                            "scrollHitchRatio": String(format: "%.4f", hitchRatio)
                        ]
                    )
                }
            }

            TelemetryStore.shared.record(
                name: "metrickit_payload_received",
                level: .info,
                properties: [
                    "payloadCount": "\(payloadCount)"
                ]
            )
        }
    }
}
