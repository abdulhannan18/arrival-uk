import Foundation

#if os(iOS)
import UIKit
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@available(iOS 17.0, *)
final class ArrivalAppDelegateBridge: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let apsPayload = userInfo["aps"] as? [AnyHashable: Any]
        let contentAvailable = (apsPayload?["content-available"] as? Int == 1) ||
            (apsPayload?["content-available"] as? String == "1")

        Task { @MainActor in
            let result = await PushNotificationManager.shared.handleRemoteNotificationPayload(
                userInfo,
                isSilent: contentAvailable
            )
            completionHandler(result)
        }
    }
}
#endif
