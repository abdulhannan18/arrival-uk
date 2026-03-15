import Foundation
import os

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashLogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}

/// Centralized crash and diagnostics reporting.
/// Works without Firebase, and automatically forwards logs/errors to Crashlytics when linked.
enum CrashReporter {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.arrivaluk.app",
        category: "crash-reporter"
    )
    private static let syncQueue = DispatchQueue(label: "com.arrivaluk.crash-reporter")
    private static var didBootstrap = false
    private static var didConfigureAppCheck = false

    static func bootstrapIfNeeded() {
        syncQueue.sync {
            guard !didBootstrap else { return }
            didBootstrap = true
        }

        CrashSessionGuard.installIfNeeded()

        #if canImport(FirebaseCore)
        configureAppCheckIfNeeded()
        if FirebaseApp.app() == nil {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                FirebaseApp.configure()
            } else {
                logger.warning("GoogleService-Info.plist missing; Firebase not configured in this build")
            }
        }
        #endif

        let environment = AppConfig.environment.rawValue
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(environment, forKey: "app_environment")
        crashlytics.setCustomValue(version, forKey: "app_version")
        crashlytics.setCustomValue(build, forKey: "app_build")
        crashlytics.log("CrashReporter bootstrapped env=\(environment) version=\(version) build=\(build)")
        #endif

        log("CrashReporter bootstrapped env=\(environment) version=\(version) build=\(build)", level: .info)
    }

    #if canImport(FirebaseAppCheck)
    private static func configureAppCheckIfNeeded() {
        syncQueue.sync {
            guard !didConfigureAppCheck else { return }
            didConfigureAppCheck = true
            AppCheck.setAppCheckProviderFactory(ArrivalAppCheckProviderFactory())
        }
    }
    #else
    private static func configureAppCheckIfNeeded() {}
    #endif

    static func setUserIdentifier(_ identifier: String?) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(identifier ?? "")
        #endif
    }

    static func log(_ message: String, level: CrashLogLevel = .info) {
        switch level {
        case .debug:
            #if DEBUG
            logger.debug("\(message, privacy: .public)")
            #endif
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error, .critical:
            logger.error("\(message, privacy: .public)")
        }

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("[\(String(describing: level).uppercased())] \(message)")
        #endif
    }

    static func record(
        error: Error,
        context: String,
        metadata: [String: String] = [:]
    ) {
        let nsError = error as NSError
        logger.error(
            "nonfatal context=\(context, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
        )

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(context, forKey: "last_error_context")
        if !metadata.isEmpty {
            crashlytics.setCustomValue(metadata, forKey: "last_error_metadata")
        }
        crashlytics.record(error: nsError)
        #endif
    }
}

#if canImport(FirebaseAppCheck)
private final class ArrivalAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
        #endif
    }
}
#endif
