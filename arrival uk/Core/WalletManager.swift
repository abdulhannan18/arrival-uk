import Foundation
import LocalAuthentication
import Observation
import Security
import SwiftUI
import UIKit

@Observable
final class WalletManager {
    var isUnlocked = false
    var isPrivacyShieldActive = true
    var documents: [SecureDoc] = []
    var phase4Config = Phase4WalletConfig.default

    private var hasBootstrapped = false
    private let storageKey = StorageKey.walletDocumentsSecure.rawValue
    private let documentIntelligence = DocumentIntelligence.shared

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadDocumentsFromSecureStore()
        ensureRequiredDocumentsPresent()
    }

    @MainActor
    func requestAccess() {
        Task { @MainActor in
            _ = await requestAccessAsync()
        }
    }

    @MainActor
    func requestAccessAsync() async -> Bool {
        guard phase4Config.biometricEnforced else {
            isUnlocked = true
            loadDocumentsFromSecureStore()
            Haptics.successIfAllowed()
            TelemetryStore.shared.record(
                name: "wallet_unlocked_without_biometrics",
                level: .warning
            )
            return true
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = false
            Haptics.selectionIfAllowed()
            return false
        }

        let isAuthorized = await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Access your \(RegionRuntime.activeConfiguration.displayName) entry documents"
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }

        isUnlocked = isAuthorized
        if isAuthorized {
            loadDocumentsFromSecureStore()
            Haptics.successIfAllowed()
        } else {
            Haptics.selectionIfAllowed()
        }
        return isAuthorized
    }

    @MainActor
    func lock() {
        isUnlocked = false
    }

    @MainActor
    func focusDocumentType(_ type: SecureDocType) {
        guard let index = documents.firstIndex(where: { $0.type == type }) else { return }
        guard index != 0 else { return }
        let focused = documents.remove(at: index)
        documents.insert(focused, at: 0)
        persistDocumentsToSecureStore()
    }

    @MainActor
    func focusDocument(id documentID: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        guard index != 0 else { return }
        let focused = documents.remove(at: index)
        documents.insert(focused, at: 0)
        persistDocumentsToSecureStore()
    }

    @MainActor
    func analyzeAndStoreDocument(_ image: UIImage) async -> Bool {
        guard isUnlocked else { return false }
        guard let classification = await documentIntelligence.analyze(image: image) else {
            TelemetryStore.shared.record(
                name: "wallet_document_auto_classify_failed",
                level: .warning
            )
            return false
        }

        let candidate = SecureDoc(
            type: classification.type,
            holderName: "Student",
            reference: maskedReference(for: classification.type),
            status: .pending,
            lastUpdatedAt: .now,
            classificationSource: .visionOCR,
            classificationConfidence: classification.confidence
        )
        upsertClassifiedDocument(candidate)

        TelemetryStore.shared.record(
            name: "wallet_document_auto_classified",
            level: .info,
            properties: [
                "docType": classification.type.rawValue,
                "confidence": String(format: "%.2f", classification.confidence),
                "requestRevision": "\(classification.requestRevision)"
            ]
        )
        return true
    }

    @MainActor
    func overrideDocumentType(for documentID: UUID, with type: SecureDocType) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[index].type = type
        documents[index].classificationSource = .manual
        documents[index].classificationConfidence = nil
        documents[index].lastUpdatedAt = .now
        ensureRequiredDocumentsPresent()
        persistDocumentsToSecureStore()

        TelemetryStore.shared.record(
            name: "wallet_document_category_override",
            level: .info,
            properties: [
                "docType": type.rawValue
            ]
        )
    }

    @MainActor
    func apply(config: Phase4WalletConfig) {
        phase4Config = config
        ensureRequiredDocumentsPresent()
    }

    @MainActor
    func handleScenePhaseChange(_ phase: ScenePhase) {
        isPrivacyShieldActive = phase != .active
        if phase == .inactive || phase == .background {
            isUnlocked = false
        }
    }

    @MainActor
    private func loadDocumentsFromSecureStore() {
        guard let data = KeychainManager.load(for: storageKey) else {
            documents = Self.defaultDocuments
            persistDocumentsToSecureStore()
            return
        }

        do {
            documents = try JSONDecoder().decode([SecureDoc].self, from: data)
            ensureRequiredDocumentsPresent()
        } catch {
            CrashReporter.record(error: error, context: "wallet_documents_decode")
            documents = Self.defaultDocuments
            ensureRequiredDocumentsPresent()
            persistDocumentsToSecureStore()
        }
    }

    @MainActor
    private func persistDocumentsToSecureStore() {
        do {
            let encoded = try JSONEncoder().encode(documents)
            try KeychainManager.saveThrowing(
                data: encoded,
                for: storageKey,
                accessibility: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            )
        } catch {
            CrashReporter.record(error: error, context: "wallet_documents_persist")
        }
    }

    @MainActor
    private func ensureRequiredDocumentsPresent() {
        guard !phase4Config.requiredDocuments.isEmpty else { return }
        var didMutate = false
        let requiredTypes = Set(phase4Config.requiredDocuments.map(\.secureDocType))

        for required in phase4Config.requiredDocuments {
            let requiredType = required.secureDocType
            if documents.contains(where: { $0.type == requiredType }) {
                continue
            }
            documents.append(templateDocument(for: required))
            didMutate = true
        }

        let previousCount = documents.count
        documents.removeAll { document in
            guard !requiredTypes.contains(document.type) else { return false }
            return document.classificationSource == .remoteTemplate
        }
        if documents.count != previousCount {
            didMutate = true
        }

        let ordering = Dictionary(
            uniqueKeysWithValues: phase4Config.requiredDocuments.enumerated().map { index, doc in
                (doc.secureDocType, index)
            }
        )
        documents.sort { lhs, rhs in
            let lhsOrder = ordering[lhs.type] ?? Int.max
            let rhsOrder = ordering[rhs.type] ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.lastUpdatedAt > rhs.lastUpdatedAt
        }

        if didMutate {
            persistDocumentsToSecureStore()
        }
    }

    private func templateDocument(for required: WalletRequiredDocument) -> SecureDoc {
        switch required {
        case .passport:
            return SecureDoc(
                type: .passport,
                holderName: "Student",
                reference: "P1234***",
                status: .verified,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .brp:
            return SecureDoc(
                type: .studentVisa,
                holderName: "Student",
                reference: "BRP-UK-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .universityCAS:
            return SecureDoc(
                type: .casLetter,
                holderName: "Student",
                reference: "CAS-REF-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .tenancy:
            return SecureDoc(
                type: .tenancyAgreement,
                holderName: "Student",
                reference: "LEASE-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .ssn:
            return SecureDoc(
                type: .nationalID,
                holderName: "Student",
                reference: "SSN-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .sin:
            return SecureDoc(
                type: .nationalID,
                holderName: "Student",
                reference: "SIN-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .tfn:
            return SecureDoc(
                type: .nationalID,
                holderName: "Student",
                reference: "TFN-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        case .nationalID:
            return SecureDoc(
                type: .nationalID,
                holderName: "Student",
                reference: "ID-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        }
    }

    @MainActor
    private func upsertClassifiedDocument(_ classified: SecureDoc) {
        if let existingIndex = documents.firstIndex(where: { document in
            document.type == classified.type &&
                (document.classificationSource == .remoteTemplate || document.reference.contains("***"))
        }) {
            var updated = documents[existingIndex]
            updated.type = classified.type
            updated.reference = classified.reference
            updated.status = classified.status
            updated.lastUpdatedAt = classified.lastUpdatedAt
            updated.classificationSource = classified.classificationSource
            updated.classificationConfidence = classified.classificationConfidence
            documents[existingIndex] = updated
        } else {
            documents.insert(classified, at: 0)
        }

        ensureRequiredDocumentsPresent()
        persistDocumentsToSecureStore()
    }

    private func maskedReference(for type: SecureDocType) -> String {
        switch type {
        case .passport:
            return "PASS-CLASSIFIED"
        case .studentVisa:
            return "BRP-CLASSIFIED"
        case .casLetter:
            return "CAS-CLASSIFIED"
        case .tenancyAgreement:
            return "LEASE-CLASSIFIED"
        case .nationalID:
            return "ID-CLASSIFIED"
        }
    }

    private static var defaultDocuments: [SecureDoc] {
        [
            SecureDoc(
                type: .passport,
                holderName: "Student",
                reference: "P1234***",
                status: .verified,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            ),
            SecureDoc(
                type: .studentVisa,
                holderName: "Student",
                reference: "VISA-2026-***",
                status: .verified,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            ),
            SecureDoc(
                type: .casLetter,
                holderName: "Student",
                reference: "CAS-REF-***",
                status: .pending,
                lastUpdatedAt: .now,
                classificationSource: .remoteTemplate
            )
        ]
    }
}
