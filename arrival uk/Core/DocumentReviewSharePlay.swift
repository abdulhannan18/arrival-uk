import Foundation
import Observation

#if canImport(GroupActivities)
import GroupActivities
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct ArrivalDocumentReviewActivity: GroupActivity {
    let documentID: String
    let token: String
    let redactedMode: Bool

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Arrival UK Document Review"
        metadata.type = .generic
        return metadata
    }
}

@available(iOS 17.0, *)
@MainActor
@Observable
final class DocumentReviewSharePlayCoordinator {
    static let shared = DocumentReviewSharePlayCoordinator()

    var isSessionActive = false
    var lastRedactedMode = true
    var lastSharedDocumentID: String?

    private init() {}

    func startReview(for document: SecureDoc, redactedMode: Bool) async -> Bool {
        let collaboratorID = resolvedCollaboratorID()
        guard let token = WalletShareAuthorizationService.issueToken(
            documentID: document.id,
            issuedBy: collaboratorID,
            ttlSeconds: 300,
            allowsSensitiveFields: !redactedMode
        ),
        let encodedToken = WalletShareAuthorizationService.encodeToken(token) else {
            return false
        }

        let activity = ArrivalDocumentReviewActivity(
            documentID: document.id.uuidString,
            token: encodedToken,
            redactedMode: redactedMode
        )

        do {
            let result = await activity.prepareForActivation()
            switch result {
            case .activationDisabled:
                return false
            case .activationPreferred:
                _ = try await activity.activate()
            case .cancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            CrashReporter.record(error: error, context: "phase13_shareplay_start")
            return false
        }

        lastRedactedMode = redactedMode
        lastSharedDocumentID = document.id.uuidString
        isSessionActive = true
        return true
    }

    private func resolvedCollaboratorID() -> String {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        return AuthenticationManager.shared?.currentUser?.uid ?? "local"
        #else
        return "local"
        #endif
    }

    func redactedReferenceIfNeeded(for document: SecureDoc, encodedToken: String?) -> String {
        guard let encodedToken,
              let token = WalletShareAuthorizationService.decodeToken(encodedToken),
              WalletShareAuthorizationService.validate(token),
              token.documentID == document.id.uuidString else {
            return "••••••"
        }

        if token.allowsSensitiveFields {
            return document.reference
        }

        let suffix = document.reference.suffix(4)
        return "••••\(suffix)"
    }
}

#else

@available(iOS 17.0, *)
@MainActor
@Observable
final class DocumentReviewSharePlayCoordinator {
    static let shared = DocumentReviewSharePlayCoordinator()
    var isSessionActive = false
    var lastRedactedMode = true
    var lastSharedDocumentID: String?

    private init() {}

    func startReview(for document: SecureDoc, redactedMode: Bool) async -> Bool {
        false
    }

    func redactedReferenceIfNeeded(for document: SecureDoc, encodedToken: String?) -> String {
        document.reference
    }
}

#endif
