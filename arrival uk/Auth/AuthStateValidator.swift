import Foundation

struct AuthStateValidator {
    private static let emailRegex: NSRegularExpression? = {
        do {
            return try NSRegularExpression(
                pattern: #"^(?=.{3,254}$)[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,63}$"#,
                options: [.caseInsensitive]
            )
        } catch {
            assertionFailure("Failed to compile email regex: \(error)")
            return nil
        }
    }()

    static func isValidEmail(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return false }
        guard let emailRegex else {
            return email.contains("@") && email.contains(".")
        }
        let range = NSRange(email.startIndex..<email.endIndex, in: email)
        return emailRegex.firstMatch(in: email, options: [], range: range) != nil
    }

    static func normalize(_ snapshot: StudentProfileSnapshot) -> StudentProfileSnapshot {
        var normalized = snapshot

        switch snapshot.authProvider {
        case .none:
            normalized.appleUserID = nil
            normalized.googleUserID = nil

        case .apple:
            let appleID = snapshot.appleUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if appleID?.isEmpty ?? true {
                normalized.authProvider = .none
                normalized.appleUserID = nil
                normalized.email = ""
            }
            normalized.googleUserID = nil

        case .google:
            let googleID = snapshot.googleUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedEmail = snapshot.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Google mode is valid with either Google user ID or a valid email fallback.
            let hasValidGoogleIdentity = !(googleID?.isEmpty ?? true) || isValidEmail(normalizedEmail)
            if !hasValidGoogleIdentity {
                normalized.authProvider = .none
                normalized.googleUserID = nil
                normalized.email = ""
            }
            normalized.appleUserID = nil
        }

        // Keep profile completion state coherent.
        if normalized.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            normalized.selectedUniversity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.hasCompletedSetup = false
        }

        return normalized
    }
}
