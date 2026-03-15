import Foundation
import Combine

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseCore

@available(iOS 17.0, *)
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared: AuthenticationManager? = AuthenticationManager()

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false

    private let auth: Auth
    private let db: Firestore
    private let functions: Functions

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    private init?() {
        guard let firebaseApp = FirebaseApp.app() else {
            CrashReporter.log("auth_manager_init_skipped_missing_firebase_app", level: .warning)
            return nil
        }

        self.auth = Auth.auth(app: firebaseApp)
        self.db = Firestore.firestore(app: firebaseApp)
        self.functions = Functions.functions(app: firebaseApp)

        listenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                self.isAuthenticated = user != nil
                if let user {
                    await self.syncUserProfile(userId: user.uid)
                }
            }
        }
    }

    deinit {
        if let listenerHandle {
            auth.removeStateDidChangeListener(listenerHandle)
        }
    }

    func signOut() async throws {
        await PushNotificationManager.shared.unregisterDeviceTokenFromBackend()
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthBridgeError.notAuthenticated
        }
        try await user.delete()
        currentUser = nil
        isAuthenticated = false
    }

    func trackLogin(platform: String = "ios") async {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        do {
            _ = try await functions.httpsCallable("trackLogin").call([
                "platform": platform,
                "appVersion": version,
            ])
        } catch {
            CrashReporter.record(error: error, context: "auth_track_login")
        }
    }

    func trackHomeInteraction(event: String, properties: [String: Any] = [:]) async {
        guard currentUser != nil else { return }

        let trimmedEvent = event
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(64)
        guard !trimmedEvent.isEmpty else { return }

        let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"

        do {
            _ = try await functions.httpsCallable("recordAnalyticsEvent").call([
                "eventType": String(trimmedEvent),
                "properties": sanitizedAnalyticsProperties(properties),
                "platform": "ios",
                "appVersion": appVersion,
            ])
        } catch {
            CrashReporter.record(error: error, context: "auth_track_home_interaction")
        }
    }

    func verifyUserProfile() async {
        do {
            _ = try await functions.httpsCallable("verifyUser").call([:])
        } catch {
            CrashReporter.record(error: error, context: "auth_verify_user")
        }
    }

    func latestSupportTicketID() -> String {
        guard let userID = currentUser?.uid else { return "" }
        let key = supportLatestTicketIDStorageKey(for: userID)
        return UserDefaults.standard.string(forKey: key) ?? ""
    }

    func createSupportTicket(
        subject: String,
        message: String,
        category: String? = nil,
        priority: String? = nil,
        metadata: [String: Any] = [:]
    ) async throws -> String {
        guard let userID = currentUser?.uid else {
            throw AuthBridgeError.notAuthenticated
        }

        let normalizedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSubject.isEmpty, !normalizedMessage.isEmpty else {
            throw AuthBridgeError.invalidResponse
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        var payload: [String: Any] = [
            "subject": String(normalizedSubject.prefix(160)),
            "message": String(normalizedMessage.prefix(4_000)),
            "platform": "ios",
            "appVersion": appVersion,
            "metadata": sanitizedSupportMetadata(metadata),
        ]
        if let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["category"] = String(category.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        }
        if let priority, !priority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["priority"] = String(priority.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
        }

        let result = try await functions.httpsCallable("createSupportTicket").call(payload)
        guard let response = result.data as? [String: Any],
              let ticketID = response["ticketId"] as? String,
              !ticketID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AuthBridgeError.invalidResponse
        }

        let storageKey = supportLatestTicketIDStorageKey(for: userID)
        UserDefaults.standard.set(ticketID, forKey: storageKey)

        return ticketID
    }

    func addSupportTicketMessage(
        ticketId: String,
        message: String,
        metadata: [String: Any] = [:]
    ) async throws -> String {
        guard let userID = currentUser?.uid else {
            throw AuthBridgeError.notAuthenticated
        }

        let normalizedTicketID = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTicketID.isEmpty, !normalizedMessage.isEmpty else {
            throw AuthBridgeError.invalidResponse
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let payload: [String: Any] = [
            "ticketId": String(normalizedTicketID.prefix(128)),
            "message": String(normalizedMessage.prefix(4_000)),
            "platform": "ios",
            "appVersion": appVersion,
            "metadata": sanitizedSupportMetadata(metadata),
        ]

        let result = try await functions.httpsCallable("addSupportTicketMessage").call(payload)
        guard let response = result.data as? [String: Any],
              let messageID = response["messageId"] as? String,
              !messageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AuthBridgeError.invalidResponse
        }

        let storageKey = supportLatestTicketIDStorageKey(for: userID)
        UserDefaults.standard.set(normalizedTicketID, forKey: storageKey)

        return messageID
    }

    private func syncUserProfile(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            guard let payload = document.data() else { return }
            StudentProfileStore.shared.syncFromRemote(payload)
        } catch {
            CrashReporter.record(error: error, context: "auth_sync_profile")
        }
    }

    private func sanitizedAnalyticsProperties(_ properties: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (rawKey, rawValue) in properties {
            let key = rawKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(40)
            guard !key.isEmpty else { continue }

            switch rawValue {
            case let value as String:
                sanitized[String(key)] = String(value.prefix(160))
            case let value as Bool:
                sanitized[String(key)] = value
            case let value as Int:
                sanitized[String(key)] = value
            case let value as Double:
                sanitized[String(key)] = value
            case let value as Float:
                sanitized[String(key)] = Double(value)
            case let value as Date:
                sanitized[String(key)] = ISO8601DateFormatter().string(from: value)
            default:
                continue
            }
        }

        return sanitized
    }

    private func sanitizedSupportMetadata(_ metadata: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (rawKey, rawValue) in metadata {
            let key = rawKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(40)
            guard !key.isEmpty else { continue }

            switch rawValue {
            case let value as String:
                sanitized[String(key)] = String(value.prefix(200))
            case let value as Bool:
                sanitized[String(key)] = value
            case let value as Int:
                sanitized[String(key)] = value
            case let value as Double:
                sanitized[String(key)] = value
            case let value as Float:
                sanitized[String(key)] = Double(value)
            default:
                continue
            }

            if sanitized.count >= 20 {
                break
            }
        }

        return sanitized
    }

    private func supportLatestTicketIDStorageKey(for userID: String) -> String {
        "\(StorageKey.supportLatestTicketIDPrefix.rawValue)\(userID)"
    }
}

enum AuthBridgeError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case featureUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        case .invalidResponse:
            return "The server response was invalid."
        case .featureUnavailable:
            return "This feature is unavailable in the current build."
        }
    }
}

@available(iOS 17.0, *)
extension StudentProfileStore {
    @MainActor
    func syncFromRemote(_ payload: [String: Any]) {
        // Intentionally conservative mapping: only sync known safe profile fields.
        if let fullName = payload["displayName"] as? String,
           self.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.fullName = fullName
        }

        if let email = payload["email"] as? String,
           !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.email = email
        }

        if let profile = payload["profile"] as? [String: Any] {
            if let university = profile["university"] as? String,
               !university.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.selectedUniversity = university
            }
            if let city = profile["city"] as? String,
               !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.city = city
            }
            if let course = profile["course"] as? String,
               !course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.courseName = course
            }
        }

        // Persist through existing local serialization path.
        self.updateProfile(
            fullName: self.fullName,
            selectedUniversity: self.selectedUniversity,
            courseName: self.courseName,
            city: self.city,
            studyLevel: self.studyLevel,
            arrivalDate: self.arrivalDate
        )
    }
}

#else

@available(iOS 17.0, *)
@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared: AuthenticationManager? = AuthenticationManager()

    @Published private(set) var currentUser: Any?
    @Published private(set) var isAuthenticated = false

    private init() {}

    func signOut() async throws {}
    func deleteAccount() async throws {}
    func trackLogin(platform: String = "ios") async {}
    func trackHomeInteraction(event: String, properties: [String: Any] = [:]) async {}
    func verifyUserProfile() async {}
    func latestSupportTicketID() -> String { "" }
    func createSupportTicket(
        subject: String,
        message: String,
        category: String? = nil,
        priority: String? = nil,
        metadata: [String: Any] = [:]
    ) async throws -> String {
        throw AuthBridgeError.featureUnavailable
    }
    func addSupportTicketMessage(
        ticketId: String,
        message: String,
        metadata: [String: Any] = [:]
    ) async throws -> String {
        throw AuthBridgeError.featureUnavailable
    }
}

#endif
