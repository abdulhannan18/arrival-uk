import Foundation
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct GoogleSignInIdentity {
    let userID: String
    let email: String
    let fullName: String?
}

enum GoogleSignInBridgeError: LocalizedError {
    case sdkNotLinked
    case missingClientID
    case missingReversedClientID
    case missingURLScheme(String)
    case missingPresenter
    case missingEmail
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sdkNotLinked:
            return "Google Sign-In SDK is not linked in this build."
        case .missingClientID:
            return "Google client ID is missing. Add GoogleService-Info.plist first."
        case .missingReversedClientID:
            return "Google reversed client ID is missing. Ensure GoogleService-Info.plist contains REVERSED_CLIENT_ID."
        case .missingURLScheme(let scheme):
            return "Missing URL scheme '\(scheme)' in app Info settings. Add it to URL Types so Google can return to the app."
        case .missingPresenter:
            return "Could not find an active screen to present Google Sign-In."
        case .missingEmail:
            return "Google account did not return an email."
        case .cancelled:
            return "Google Sign-In was cancelled."
        }
    }
}

@MainActor
enum GoogleSignInBridge {
    static var isSDKLinked: Bool {
        #if canImport(GoogleSignIn)
        return true
        #else
        return false
        #endif
    }

    static func handle(url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    static func signOut() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    static func signIn(presenting: UIViewController?) async throws -> GoogleSignInIdentity {
        #if canImport(GoogleSignIn)
        guard let presenting else {
            throw GoogleSignInBridgeError.missingPresenter
        }

        guard let clientID = readClientID() else {
            throw GoogleSignInBridgeError.missingClientID
        }
        guard let reversedClientID = readReversedClientID() else {
            throw GoogleSignInBridgeError.missingReversedClientID
        }
        guard hasURLScheme(reversedClientID) else {
            throw GoogleSignInBridgeError.missingURLScheme(reversedClientID)
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let email = result.user.profile?.email else {
                throw GoogleSignInBridgeError.missingEmail
            }

            return GoogleSignInIdentity(
                userID: result.user.userID ?? email.lowercased(),
                email: email.lowercased(),
                fullName: result.user.profile?.name
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
                throw GoogleSignInBridgeError.cancelled
            }
            throw error
        }
        #else
        throw GoogleSignInBridgeError.sdkNotLinked
        #endif
    }

    private static func readClientID() -> String? {
        if let infoClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !infoClientID.isEmpty {
            return infoClientID
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let clientID = plist["CLIENT_ID"] as? String,
            !clientID.isEmpty
        else {
            return nil
        }

        return clientID
    }

    private static func readReversedClientID() -> String? {
        if
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            !urlTypes.isEmpty
        {
            for entry in urlTypes {
                if let schemes = entry["CFBundleURLSchemes"] as? [String] {
                    for scheme in schemes where !scheme.isEmpty {
                        if scheme.contains("com.googleusercontent.apps.") {
                            return scheme
                        }
                    }
                }
            }
        }

        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let reversed = plist["REVERSED_CLIENT_ID"] as? String,
            !reversed.isEmpty
        else {
            return nil
        }

        return reversed
    }

    private static func hasURLScheme(_ expectedScheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for entry in urlTypes {
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in schemes where scheme.caseInsensitiveCompare(expectedScheme) == .orderedSame {
                return true
            }
        }

        return false
    }
}

@MainActor
enum PresentationAnchor {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard
            let window = activeScene?.windows.first(where: \.isKeyWindow),
            let root = window.rootViewController
        else {
            return nil
        }

        return topMostViewController(from: root)
    }

    private static func topMostViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        }

        if let navigation = root as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }

        if let tabBar = root as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return topMostViewController(from: selected)
        }

        return root
    }
}
