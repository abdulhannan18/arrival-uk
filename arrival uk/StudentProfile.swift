import Foundation
import Observation
import AuthenticationServices

enum StudentAuthProvider: String, Codable, Hashable {
    case none
    case apple
    case google

    var label: String {
        switch self {
        case .none:
            return "Not signed in"
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }
}

enum StudyLevel: String, CaseIterable, Codable, Hashable {
    case foundation
    case undergraduate
    case postgraduate
    case phd
    case other

    var label: String {
        switch self {
        case .foundation:
            return "Foundation"
        case .undergraduate:
            return "Undergraduate"
        case .postgraduate:
            return "Postgraduate"
        case .phd:
            return "PhD"
        case .other:
            return "Other"
        }
    }
}

struct StudentProfileSnapshot: Codable, Equatable {
    var authProvider: StudentAuthProvider
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String
    var email: String
    var selectedUniversity: String
    var courseName: String
    var city: String
    var studyLevel: StudyLevel
    var arrivalDate: Date
    var hasCompletedSetup: Bool
    var passportNumber: String = ""
    var ukAddress: String = ""
    var universityCAS: String = ""
}

@Observable
final class StudentProfileStore {
    static let shared = StudentProfileStore()

    private let defaults = UserDefaults.standard
    private let encryptedStorageKey = StorageKey.studentProfileV2Encrypted.rawValue
    private let legacyStorageKey = StorageKey.studentProfileV1Legacy.rawValue
    private let profileEncryptionKey = StorageKey.studentProfileEncryptionKey.rawValue
    private let keychainAuthTokenKey = StorageKey.studentAuthToken.rawValue
    private let keychainRefreshTokenKey = StorageKey.studentAuthRefreshToken.rawValue
    private var hasBootstrapped = false
    private static let defaultArrivalDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 2
        components.day = 15
        return components.date ?? Date(timeIntervalSince1970: 1_708_761_600)
    }()

    var authProvider: StudentAuthProvider = .none
    var appleUserID: String?
    var googleUserID: String?
    var fullName: String = ""
    var email: String = ""
    var selectedUniversity: String = ""
    var courseName: String = ""
    var city: String = ""
    var studyLevel: StudyLevel = .undergraduate
    var arrivalDate: Date = defaultArrivalDate
    var hasCompletedSetup: Bool = false
    var passportNumber: String = ""
    var ukAddress: String = ""
    var universityCAS: String = ""

    var preferredFirstName: String? {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: " ").first.map(String.init)
    }

    private init() {}

    @MainActor
    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadFromDefaults()
    }

    @MainActor
    func setGoogleMode() {
        authProvider = .google
        appleUserID = nil
        googleUserID = nil
        persist()
    }

    @MainActor
    func setGoogleIdentity(email: String, userID: String? = nil) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthStateValidator.isValidEmail(normalizedEmail) else { return }
        authProvider = .google
        appleUserID = nil
        googleUserID = userID
        self.email = normalizedEmail.lowercased()
        persist()
    }

    @MainActor
    func applyGoogleIdentity(_ identity: GoogleSignInIdentity) {
        authProvider = .google
        appleUserID = nil
        googleUserID = identity.userID
        email = identity.email.lowercased()
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = identity.fullName,
           !name.isEmpty {
            fullName = name
        }
        persist()
    }

    @MainActor
    func clearAuthentication() {
        authProvider = .none
        appleUserID = nil
        googleUserID = nil
        email = ""
        persist()
    }

    /// Clears all local authentication state including any future Keychain-backed session secrets.
    @MainActor
    func secureSignOut() {
        secureSignOut(contentStore: .shared)
    }

    @MainActor
    func secureSignOut(contentStore: ContentStore) {
        logout(contentStore: contentStore)
    }

    /// Full local logout: clears auth, profile fields, and optional checklist progress.
    @MainActor
    func logout() {
        logout(contentStore: .shared)
    }

    @MainActor
    func logout(contentStore: ContentStore) {
        authProvider = .none
        appleUserID = nil
        googleUserID = nil
        fullName = ""
        email = ""
        selectedUniversity = ""
        courseName = ""
        city = ""
        studyLevel = .undergraduate
        arrivalDate = Self.defaultArrivalDate
        hasCompletedSetup = false
        passportNumber = ""
        ukAddress = ""
        universityCAS = ""

        EncryptedDefaultsStore.wipe(
            storageKey: encryptedStorageKey,
            keychainKey: profileEncryptionKey,
            defaults: defaults
        )
        defaults.removeObject(forKey: legacyStorageKey)
        _ = KeychainManager.delete(for: keychainAuthTokenKey)
        _ = KeychainManager.delete(for: keychainRefreshTokenKey)
        contentStore.clearAllProgress()
        syncCrashReporterIdentity()
    }

    @MainActor
    func applyAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        authProvider = .apple
        appleUserID = credential.user
        googleUserID = nil

        if let email = credential.email, !email.isEmpty {
            self.email = email.lowercased()
        }

        if let givenName = credential.fullName?.givenName, !givenName.isEmpty {
            let familyName = credential.fullName?.familyName ?? ""
            let combined = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                fullName = combined
            }
        }

        persist()
    }

    @MainActor
    func updateProfile(
        fullName: String,
        selectedUniversity: String,
        courseName: String,
        city: String,
        studyLevel: StudyLevel,
        arrivalDate: Date
    ) {
        self.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedUniversity = selectedUniversity.trimmingCharacters(in: .whitespacesAndNewlines)
        self.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        self.studyLevel = studyLevel
        self.arrivalDate = arrivalDate
        hasCompletedSetup = !self.fullName.isEmpty && !self.selectedUniversity.isEmpty
        persist()
    }

    @MainActor
    private func loadFromDefaults() {
        let decoded: StudentProfileSnapshot?
        var shouldMigrateLegacySnapshot = false

        if let encryptedData = try? EncryptedDefaultsStore.load(
            for: encryptedStorageKey,
            keychainKey: profileEncryptionKey,
            defaults: defaults
        ) {
            decoded = try? JSONDecoder().decode(StudentProfileSnapshot.self, from: encryptedData)
        } else if
            let legacyData = defaults.data(forKey: legacyStorageKey),
            let legacyDecoded = try? JSONDecoder().decode(StudentProfileSnapshot.self, from: legacyData)
        {
            decoded = legacyDecoded
            shouldMigrateLegacySnapshot = true
        } else {
            decoded = nil
        }

        guard let decoded else { return }

        let snapshot = AuthStateValidator.normalize(decoded)

        authProvider = snapshot.authProvider
        appleUserID = snapshot.appleUserID
        googleUserID = snapshot.googleUserID
        fullName = snapshot.fullName
        email = snapshot.email
        selectedUniversity = snapshot.selectedUniversity
        courseName = snapshot.courseName
        city = snapshot.city
        studyLevel = snapshot.studyLevel
        arrivalDate = snapshot.arrivalDate
        hasCompletedSetup = snapshot.hasCompletedSetup
        passportNumber = snapshot.passportNumber
        ukAddress = snapshot.ukAddress
        universityCAS = snapshot.universityCAS

        // If the snapshot required normalization, immediately persist the corrected state.
        if snapshot != decoded {
            persist()
        } else if shouldMigrateLegacySnapshot {
            // One-time migration from plaintext defaults to encrypted profile storage.
            persist()
        } else {
            syncCrashReporterIdentity()
        }
    }

    @MainActor
    private func persist() {
        let snapshot = StudentProfileSnapshot(
            authProvider: authProvider,
            appleUserID: appleUserID,
            googleUserID: googleUserID,
            fullName: fullName,
            email: email,
            selectedUniversity: selectedUniversity,
            courseName: courseName,
            city: city,
            studyLevel: studyLevel,
            arrivalDate: arrivalDate,
            hasCompletedSetup: hasCompletedSetup,
            passportNumber: passportNumber,
            ukAddress: ukAddress,
            universityCAS: universityCAS
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try EncryptedDefaultsStore.save(
                data,
                for: encryptedStorageKey,
                keychainKey: profileEncryptionKey,
                defaults: defaults
            )
            defaults.removeObject(forKey: legacyStorageKey)
        } catch {
            CrashReporter.record(error: error, context: "student_profile_persist_encrypted")
        }
        syncCrashReporterIdentity()
    }

    @MainActor
    private func syncCrashReporterIdentity() {
        let identifier: String?

        switch authProvider {
        case .apple:
            identifier = appleUserID
        case .google:
            identifier = googleUserID
        case .none:
            identifier = nil
        }

        CrashReporter.setUserIdentifier(identifier)
    }
}

enum UniversityCatalog {
    static let popularUK: [String] = [
        "University of Oxford",
        "University of Cambridge",
        "Imperial College London",
        "UCL",
        "King's College London",
        "University of Edinburgh",
        "University of Manchester",
        "University of Birmingham",
        "University of Leeds",
        "University of Glasgow",
        "University of Bristol",
        "University of Nottingham",
        "University of Sheffield",
        "University of Warwick",
        "Queen Mary University of London",
        "University of Southampton",
        "Newcastle University",
        "University of Liverpool",
        "University of York",
        "University of Exeter"
    ]
}
