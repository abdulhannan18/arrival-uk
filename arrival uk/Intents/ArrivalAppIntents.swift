import AppIntents
import Foundation
import OSLog
import UIKit

private enum ArrivalIntentRoutes {
    static let scheme = "arrivaluk"

    static func wallet(documentType: SecureDocType?) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "wallet"
        var queryItems = [
            URLQueryItem(name: "unlock", value: "1")
        ]
        if let documentType {
            queryItems.append(URLQueryItem(name: "document", value: documentType.rawValue))
        }
        components.queryItems = queryItems
        return components.url
    }

    static func quickTask() -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "quicktask"
        return components.url
    }
}

private let intentLogger = Logger(subsystem: "com.arrivaluk.app", category: "AppIntents")

private func logIntentLatency(name: StaticString, elapsedMs: Double) {
    if elapsedMs > 200 {
        intentLogger.warning("\(name, privacy: .public) exceeded latency budget at \(elapsedMs, privacy: .public)ms")
    } else {
        intentLogger.log("\(name, privacy: .public) completed in \(elapsedMs, privacy: .public)ms")
    }
}

enum ArrivalIntentDocumentType: String, AppEnum, CaseIterable {
    case brp
    case passport
    case cas
    case tenancy

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Arrival Document")
    static let caseDisplayRepresentations: [ArrivalIntentDocumentType: DisplayRepresentation] = [
        .brp: DisplayRepresentation(title: "BRP"),
        .passport: DisplayRepresentation(title: "Passport"),
        .cas: DisplayRepresentation(title: "CAS Letter"),
        .tenancy: DisplayRepresentation(title: "Tenancy Agreement")
    ]

    var secureDocType: SecureDocType {
        switch self {
        case .brp:
            return .studentVisa
        case .passport:
            return .passport
        case .cas:
            return .casLetter
        case .tenancy:
            return .tenancyAgreement
        }
    }
}

struct ShowArrivalDocumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Arrival Document"
    static let description = IntentDescription(
        "Open Arrival UK to your secure wallet and prompt biometric access for a selected document."
    )
    static let openAppWhenRun = true

    @Parameter(title: "Document Type")
    var documentType: ArrivalIntentDocumentType

    init() {
        self.documentType = .brp
    }

    init(documentType: ArrivalIntentDocumentType) {
        self.documentType = documentType
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let startedAt = Date()
        defer {
            let elapsedMs = Date().timeIntervalSince(startedAt) * 1_000
            logIntentLatency(name: "ShowArrivalDocumentIntent", elapsedMs: elapsedMs)
        }

        guard UIApplication.shared.isProtectedDataAvailable else {
            return .result(dialog: IntentDialog("Unlock your iPhone first, then ask again for secure wallet access."))
        }

        guard let route = ArrivalIntentRoutes.wallet(documentType: documentType.secureDocType) else {
            return .result(dialog: IntentDialog("I couldn't prepare that wallet shortcut."))
        }

        ArrivalIntentRouteBridge.enqueue(
            deepLinkURL: route,
            source: "show_document_intent_\(documentType.rawValue)"
        )
        return .result(dialog: IntentDialog("Opening your secure Arrival UK wallet."))
    }
}

struct NextArrivalTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "What's My Next Task?"
    static let description = IntentDescription(
        "Get the highest-priority pending Arrival UK task."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let startedAt = Date()
        defer {
            let elapsedMs = Date().timeIntervalSince(startedAt) * 1_000
            logIntentLatency(name: "NextArrivalTaskIntent", elapsedMs: elapsedMs)
        }

        guard let snapshot = ArrivalIntentRouteBridge.latestSnapshot() else {
            return .result(
                value: "Open Arrival UK",
                dialog: IntentDialog("I couldn't find your latest queue. Open Arrival UK to refresh your tasks.")
            )
        }

        let title = snapshot.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return .result(
                value: "Open Arrival UK",
                dialog: IntentDialog("Your queue is clear. Open Arrival UK for more suggestions.")
            )
        }
        return .result(value: title, dialog: IntentDialog("Your next task is \(title)."))
    }
}

struct OpenArrivalQuickTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Next Arrival Task"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let startedAt = Date()
        defer {
            let elapsedMs = Date().timeIntervalSince(startedAt) * 1_000
            logIntentLatency(name: "OpenArrivalQuickTaskIntent", elapsedMs: elapsedMs)
        }

        guard let route = ArrivalIntentRoutes.quickTask() else {
            return .result(dialog: IntentDialog("I couldn't open your next task right now."))
        }
        ArrivalIntentRouteBridge.enqueue(deepLinkURL: route, source: "quick_task_intent")
        return .result(dialog: IntentDialog("Opening your next priority task."))
    }
}

struct ArrivalAppShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowArrivalDocumentIntent(documentType: .brp),
            phrases: [
                "Show my BRP in \(.applicationName)",
                "Open secure wallet in \(.applicationName)"
            ],
            shortTitle: "Show BRP",
            systemImageName: "person.text.rectangle"
        )
        AppShortcut(
            intent: NextArrivalTaskIntent(),
            phrases: [
                "What's my next task in \(.applicationName)",
                "Next Arrival task in \(.applicationName)"
            ],
            shortTitle: "Next Task",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: OpenArrivalQuickTaskIntent(),
            phrases: [
                "Open my priority task in \(.applicationName)"
            ],
            shortTitle: "Open Task",
            systemImageName: "bolt.badge.clock"
        )
    }
}
