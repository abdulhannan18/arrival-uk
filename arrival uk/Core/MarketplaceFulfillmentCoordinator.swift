import Foundation
import Observation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@available(iOS 17.0, *)
@MainActor
@Observable
final class MarketplaceFulfillmentCoordinator {
    static let shared = MarketplaceFulfillmentCoordinator()

    private var inFlightProviderIDs: Set<String> = []

    var lastErrorMessage: String?

    private init() {}

    func launchService(
        descriptor: MarketplaceProviderDescriptor,
        walletManager: WalletManager,
        identityTokenTTLSeconds: TimeInterval,
        entryPoint: String
    ) async -> OnboardingResult? {
        let providerID = descriptor.normalizedProviderID
        guard !providerID.isEmpty else { return nil }
        guard !inFlightProviderIDs.contains(providerID) else { return nil }

        inFlightProviderIDs.insert(providerID)
        defer { inFlightProviderIDs.remove(providerID) }
        lastErrorMessage = nil

        let isUnlocked = await walletManager.requestAccessAsync()
        guard isUnlocked else {
            lastErrorMessage = "Unlock required before sharing identity with provider."
            return nil
        }

        let paymentResult = await MarketplacePaymentCoordinator.shared.processServicePayment(for: descriptor)
        switch paymentResult {
        case .failed:
            lastErrorMessage = MarketplaceProviderError.paymentFailed.localizedDescription
            return nil
        case .cancelled:
            lastErrorMessage = "Payment cancelled."
            return nil
        case .unavailable:
            if descriptor.requiresPayment {
                lastErrorMessage = "Payment unavailable on this device."
                return nil
            }
        case .notRequired, .succeeded:
            break
        }

        let userID = resolvedUserID()
        guard let identityToken = MarketplaceIdentityTokenService.issueTemporaryToken(
            providerID: providerID,
            userID: userID,
            requestedFields: descriptor.requestedFields,
            ttlSeconds: identityTokenTTLSeconds
        ) else {
            lastErrorMessage = "Could not issue identity token."
            return nil
        }

        let provider = ServiceProviderFactory.resolveProvider(descriptor: descriptor)
        MarketplaceAnalyticsStore.shared.recordStarted(
            providerID: providerID,
            entryPoint: entryPoint
        )

        let context = MarketplaceOnboardingContext(
            providerID: providerID,
            identityToken: identityToken,
            journeyID: CollaborationSyncEngine.shared.journeyID,
            requestedFields: descriptor.requestedFields
        )

        do {
            let onboardingResult = try await provider.initiateOnboarding(context: context)
            MarketplaceAnalyticsStore.shared.recordCompleted(
                providerID: providerID,
                entryPoint: entryPoint,
                completionToken: onboardingResult.completionToken
            )
            if let completedTaskID = onboardingResult.completedTaskID {
                NotificationCenter.default.post(
                    name: .didCompleteMarketplaceTask,
                    object: nil,
                    userInfo: [
                        "taskID": completedTaskID,
                        "categoryID": onboardingResult.completedCategoryID ?? "",
                        "providerID": providerID
                    ]
                )
            }
            return onboardingResult
        } catch {
            lastErrorMessage = error.localizedDescription
            CrashReporter.record(error: error, context: "phase14_marketplace_launch_\(providerID)")
            return nil
        }
    }

    func resolveProviderFromUniversalLink(_ url: URL, config: RemoteAppConfig) -> MarketplaceProviderDescriptor? {
        guard let host = url.host?.lowercased() else { return nil }
        guard host == "arrivaluk.app" || host == "www.arrivaluk.app" else { return nil }
        guard url.path.lowercased().contains("/verify") else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let providerID = components?.queryItems?.first(where: { $0.name == "providerID" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let providerID, !providerID.isEmpty else { return nil }
        let regionProviders = RegionRuntime.filterMarketplaceProviders(config.phase14Marketplace.providers)
        return regionProviders.first(where: { $0.normalizedProviderID == providerID })
    }

    private func resolvedUserID() -> String {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        if let uid = AuthenticationManager.shared?.currentUser?.uid,
           !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return uid
        }
        #endif
        return CollaborationSyncEngine.shared.journeyID
    }
}

extension Notification.Name {
    static let didCompleteMarketplaceTask = Notification.Name("didCompleteMarketplaceTask")
}
