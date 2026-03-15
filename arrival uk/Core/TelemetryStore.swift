import Foundation
import Observation
import os

struct TelemetryEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let level: String
    let timestamp: Date
    let properties: [String: String]
}

@MainActor
@Observable
final class TelemetryStore {
    static let shared = TelemetryStore()

    nonisolated private static let maxStoredEvents = 120
    nonisolated private static let redactedValue = "[redacted]"
    nonisolated private static let piiKeyFragments = [
        "name",
        "email",
        "phone",
        "passport",
        "brp",
        "cas",
        "national_insurance",
        "ni_number",
        "birth",
        "dob",
        "account",
        "sort_code",
        "iban",
        "visa",
        "token",
        "auth",
        "reference",
        "holder",
        "address",
        "document"
    ]

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "telemetry"
    )

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private(set) var recentEvents: [TelemetryEvent] = []

    private init() {
        loadPersistedEvents()
    }

    func record(
        name: String,
        level: CrashLogLevel = .info,
        properties: [String: String] = [:]
    ) {
        let event = TelemetryEvent(
            id: UUID(),
            name: name,
            level: level.telemetryLabel,
            timestamp: Date(),
            properties: Self.sanitizeForTransport(properties)
        )

        recentEvents.append(event)
        if recentEvents.count > Self.maxStoredEvents {
            recentEvents.removeFirst(recentEvents.count - Self.maxStoredEvents)
        }
        persistEvents()

        let summary = "event=\(event.name) level=\(event.level) props=\(event.properties.count)"
        switch level {
        case .debug:
            #if DEBUG
            logger.debug("\(summary, privacy: .public)")
            #endif
        case .info:
            logger.info("\(summary, privacy: .public)")
        case .warning:
            logger.warning("\(summary, privacy: .public)")
        case .error, .critical:
            logger.error("\(summary, privacy: .public)")
        }
    }

    func recentEventsForUpload(limit: Int = 30) -> [TelemetryEvent] {
        let safeLimit = max(1, min(limit, Self.maxStoredEvents))
        return Array(recentEvents.suffix(safeLimit))
    }

    private func loadPersistedEvents() {
        guard let data = defaults.data(forKey: StorageKey.telemetryEventsCache.rawValue) else {
            recentEvents = []
            return
        }

        do {
            recentEvents = try decoder.decode([TelemetryEvent].self, from: data)
        } catch {
            recentEvents = []
            defaults.removeObject(forKey: StorageKey.telemetryEventsCache.rawValue)
            CrashReporter.record(error: error, context: "telemetry_decode")
        }
    }

    private func persistEvents() {
        do {
            let encoded = try encoder.encode(recentEvents)
            defaults.set(encoded, forKey: StorageKey.telemetryEventsCache.rawValue)
        } catch {
            CrashReporter.record(error: error, context: "telemetry_encode")
        }
    }

    nonisolated static func sanitizeForTransport(_ properties: [String: String]) -> [String: String] {
        var sanitized: [String: String] = [:]

        for (rawKey, rawValue) in properties {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            if shouldRedact(key: key) {
                sanitized[key] = redactedValue
                continue
            }

            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                sanitized[key] = ""
                continue
            }

            if containsPII(value: value) {
                sanitized[key] = redactedValue
            } else {
                sanitized[key] = String(value.prefix(180))
            }
        }

        return sanitized
    }

    nonisolated private static func shouldRedact(key: String) -> Bool {
        let loweredKey = key.lowercased()
        return piiKeyFragments.contains(where: { loweredKey.contains($0) })
    }

    nonisolated private static func containsPII(value: String) -> Bool {
        if value.contains("@") { return true }

        let digits = value.filter(\.isNumber)
        if digits.count >= 8 {
            return true
        }

        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // UK National Insurance number pattern.
        if normalized.range(
            of: #"^[A-CEGHJ-PR-TW-Z]{2}\d{6}[A-D]$"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        // Common long alpha-numeric ID pattern (passport/BRP-like tokens).
        if normalized.range(
            of: #"^(?=.*[A-Z])(?=.*\d)[A-Z0-9]{8,14}$"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        return false
    }
}

private extension CrashLogLevel {
    var telemetryLabel: String {
        switch self {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .warning:
            return "warning"
        case .error:
            return "error"
        case .critical:
            return "critical"
        }
    }
}
