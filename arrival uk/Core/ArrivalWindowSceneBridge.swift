import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ArrivalWindowSceneBridge {
    private static let stagedDocumentIDKey = "arrival.phase12.stagedDocumentID.v1"

    static func requestPinnedDocumentWindow(for documentID: UUID) {
        stagePinnedDocumentID(documentID)
        let activity = documentActivity(for: documentID)

        #if canImport(UIKit)
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil
        ) { error in
            CrashReporter.record(error: error, context: "phase12_request_pinned_document_window")
        }
        #else
        CrashReporter.log("Pinned document scene request unsupported on this platform", level: .warning)
        #endif
    }

    static func documentActivity(for documentID: UUID) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ArrivalContinuity.openDocumentActivityType)
        activity.title = "Pinned Document"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = false
        activity.userInfo = [
            ArrivalContinuity.documentIDKey: documentID.uuidString
        ]
        activity.persistentIdentifier = "document-\(documentID.uuidString)"
        return activity
    }

    static func documentID(from activity: NSUserActivity) -> UUID? {
        guard let rawValue = activity.userInfo?[ArrivalContinuity.documentIDKey] as? String else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    static func stagePinnedDocumentID(_ documentID: UUID) {
        UserDefaults.standard.set(documentID.uuidString, forKey: stagedDocumentIDKey)
    }

    static func stagedPinnedDocumentID() -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: stagedDocumentIDKey) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }
}
