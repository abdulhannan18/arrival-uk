import Foundation
import UserNotifications
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseMessaging) && canImport(FirebaseFunctions)
import FirebaseMessaging
import FirebaseFunctions
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@available(iOS 17.0, *)
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?

    /// Firebase Functions is only safe to access after Firebase has been configured.
    /// When `GoogleService-Info.plist` is absent (e.g., open-source builds, CI, tests),
    /// we run in "Firebase-disabled" mode and skip backend registration.
    private var functions: Functions? {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        return Functions.functions()
        #else
        return nil
        #endif
    }
    private let installationIDStorageKey = StorageKey.pushInstallationID.rawValue
    private let pendingFCMTokenStorageKey = StorageKey.pushPendingFCMToken.rawValue

    private override init() {
        super.init()
    }

    func configureIfNeeded() {
        UNUserNotificationCenter.current().delegate = self

        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            CrashReporter.log("Firebase not configured; push messaging disabled for this run", level: .warning)
            Task { await refreshAuthorizationStatus() }
            return
        }
        #endif

        Messaging.messaging().delegate = self
        Task {
            await refreshAuthorizationStatus()
            await retryPendingTokenRegistrationIfNeeded()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            authorizationStatus = settings.authorizationStatus
            return true
        }

        guard settings.authorizationStatus == .notDetermined else {
            authorizationStatus = settings.authorizationStatus
            return false
        }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()
            #if canImport(UIKit)
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
            return granted
        } catch {
            CrashReporter.record(error: error, context: "push_permission_request")
            return false
        }
    }

    func registerDeviceTokenWithBackend(_ token: String) async {
        guard let functions else {
            CrashReporter.log("Firebase not configured; skipping push token registration", level: .warning)
            return
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        do {
            _ = try await functions.httpsCallable("registerDeviceToken").call([
                "fcmToken": token,
                "platform": "ios",
                "appVersion": appVersion,
                "deviceId": resolvedInstallationID(),
            ])
            UserDefaults.standard.removeObject(forKey: pendingFCMTokenStorageKey)
        } catch {
            UserDefaults.standard.set(token, forKey: pendingFCMTokenStorageKey)
            CrashReporter.record(error: error, context: "push_register_device_token")
        }
    }

    func unregisterDeviceTokenFromBackend() async {
        guard let functions else {
            CrashReporter.log("Firebase not configured; skipping push token unregistration", level: .warning)
            return
        }

        var payload: [String: Any] = [
            "deviceId": resolvedInstallationID(),
        ]
        if let token = fcmToken, !token.isEmpty {
            payload["fcmToken"] = token
        }
        do {
            _ = try await functions.httpsCallable("unregisterDeviceToken").call(payload)
        } catch {
            CrashReporter.record(error: error, context: "push_unregister_device_token")
        }
    }

    private func resolvedInstallationID() -> String {
        if let persisted = KeychainManager.loadString(for: installationIDStorageKey),
           !persisted.isEmpty {
            return persisted
        }

        let defaults = UserDefaults.standard
        if let legacy = defaults.string(forKey: installationIDStorageKey),
           !legacy.isEmpty {
            if KeychainManager.saveString(legacy, for: installationIDStorageKey) {
                defaults.removeObject(forKey: installationIDStorageKey)
            } else {
                CrashReporter.log("Failed to migrate push installation ID to keychain", level: .warning)
            }
            return legacy
        }

        let generated = UUID().uuidString
        if !KeychainManager.saveString(generated, for: installationIDStorageKey) {
            // Keychain fallback keeps behavior stable even if keychain write fails.
            defaults.set(generated, forKey: installationIDStorageKey)
            CrashReporter.log("Falling back to UserDefaults for push installation ID", level: .warning)
        }
        return generated
    }

    private func retryPendingTokenRegistrationIfNeeded() async {
        let defaults = UserDefaults.standard
        guard let pendingToken = defaults.string(forKey: pendingFCMTokenStorageKey),
              !pendingToken.isEmpty
        else {
            return
        }
        await registerDeviceTokenWithBackend(pendingToken)
    }

    func handleRemoteNotificationPayload(
        _ userInfo: [AnyHashable: Any],
        isSilent: Bool
    ) async -> UIBackgroundFetchResult {
        guard isSilent else { return .noData }
        let consumed = await CollaborationSyncEngine.shared.handleSilentPushPayload(userInfo)
        return consumed ? .newData : .noData
    }
}

@available(iOS 17.0, *)
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// `UNNotificationContent.userInfo` is bridged as `[AnyHashable: Any]`, which is not `Sendable`.
    /// We only hop to `MainActor` to post a notification; treating this payload as immutable is fine
    /// for our purposes, so we wrap it as `@unchecked Sendable` to satisfy Swift 6 concurrency checks.
    private struct SendableUserInfo: @unchecked Sendable {
        let value: [AnyHashable: Any]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = SendableUserInfo(value: response.notification.request.content.userInfo)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .didTapRemoteNotification,
                object: nil,
                userInfo: userInfo.value
            )
        }
    }
}

@available(iOS 17.0, *)
extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = token
            await self.registerDeviceTokenWithBackend(token)
        }
    }
}

#else

@available(iOS 17.0, *)
@MainActor
final class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?

    private init() {}

    func configureIfNeeded() {}
    func refreshAuthorizationStatus() async {}
    func requestPermissionIfNeeded() async -> Bool { false }
    func registerDeviceTokenWithBackend(_ token: String) async {}
    func unregisterDeviceTokenFromBackend() async {}
    func handleRemoteNotificationPayload(
        _ userInfo: [AnyHashable: Any],
        isSilent: Bool
    ) async -> UIBackgroundFetchResult {
        .noData
    }
}

#endif

extension Notification.Name {
    static let didTapRemoteNotification = Notification.Name("didTapRemoteNotification")
    static let didReceiveSilentCollaborationSync = Notification.Name("didReceiveSilentCollaborationSync")
}
