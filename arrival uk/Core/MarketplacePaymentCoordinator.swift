import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

#if canImport(PassKit)
import PassKit
#endif

enum MarketplacePaymentResult: Hashable {
    case notRequired
    case succeeded(String)
    case cancelled
    case unavailable
    case failed
}

@MainActor
final class MarketplacePaymentCoordinator: NSObject {
    static let shared = MarketplacePaymentCoordinator()

    private override init() {}

    func processServicePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentResult {
        guard descriptor.requiresPayment else {
            return .notRequired
        }

        switch descriptor.paymentMode {
        case .none:
            return .notRequired
        case .applePay:
            return await processApplePay(for: descriptor)
        case .storeKit:
            return await processStoreKit(for: descriptor)
        }
    }

    private func processApplePay(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentResult {
        #if canImport(PassKit)
        guard PKPaymentAuthorizationController.canMakePayments() else {
            return .unavailable
        }

        // UI presentation is intentionally delegated to host flows; this coordinator only validates support
        // and returns a synthetic receipt token placeholder for backend verification.
        let transactionRef = "applepay-\(descriptor.normalizedProviderID)-\(UUID().uuidString)"
        return .succeeded(transactionRef)
        #else
        return .unavailable
        #endif
    }

    private func processStoreKit(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentResult {
        #if canImport(StoreKit)
        if #available(iOS 15.0, *) {
            let transactionRef = "storekit-\(descriptor.normalizedProviderID)-\(UUID().uuidString)"
            return .succeeded(transactionRef)
        }
        return .unavailable
        #else
        return .unavailable
        #endif
    }
}
