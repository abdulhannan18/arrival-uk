import CryptoKit
import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

#if canImport(PassKit)
import PassKit
#endif

nonisolated enum MarketplacePaymentError: Hashable, LocalizedError {
    case unavailable(String)
    case unverifiedReceipt(String)
    case backendConfirmationFailed(String)
    case paymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason),
             .unverifiedReceipt(let reason),
             .backendConfirmationFailed(let reason),
             .paymentFailed(let reason):
            return reason
        }
    }
}

nonisolated enum MarketplacePaymentEvent: Hashable {
    case initiated(providerID: String)
    case processing(providerID: String)
    case pendingVerification(providerID: String)
    case succeeded(receipt: String)
    case failed(MarketplacePaymentError)
    case cancelled
}

nonisolated enum MarketplacePaymentResult: Hashable {
    case notRequired
    case succeeded(String)
    case cancelled
    case pending
    case unavailable
    case failed(MarketplacePaymentError)
}

nonisolated struct MarketplaceAuthorizedPayment: Sendable {
    let transactionReference: String
    let paymentPayload: String
    let finish: (@Sendable () async -> Void)?
}

nonisolated enum MarketplacePaymentAuthorizationResult: Sendable {
    case authorized(MarketplaceAuthorizedPayment)
    case pending
    case cancelled
    case unavailable(String)
    case unverified(String)
    case failed(String)
}

nonisolated struct MarketplaceEntitlementRecord: Codable, Hashable, Sendable {
    let providerID: String
    let receipt: String
    let grantedAtMillis: Int64
}

@MainActor
protocol MarketplaceEntitlementStoring: Sendable {
    func entitlement(for providerID: String) -> MarketplaceEntitlementRecord?
    func save(_ entitlement: MarketplaceEntitlementRecord)
}

@MainActor
protocol MarketplaceApplePayAuthorizing: Sendable {
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult
}

@MainActor
protocol MarketplaceStoreKitAuthorizing: Sendable {
    func hasEntitlement(for descriptor: MarketplaceProviderDescriptor) async -> Bool
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult
    func restoreEntitlements() async -> [String]
}

@MainActor
protocol MarketplacePaymentConfirming: Sendable {
    func confirmPayment(
        for descriptor: MarketplaceProviderDescriptor,
        userID: String,
        authorization: MarketplaceAuthorizedPayment
    ) async throws -> MarketplaceEntitlementRecord
}

@MainActor
private struct MarketplaceEntitlementKeychainStore: MarketplaceEntitlementStoring {
    private let storageKey = StorageKey.marketplaceEntitlements.rawValue

    func entitlement(for providerID: String) -> MarketplaceEntitlementRecord? {
        let normalizedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedProviderID.isEmpty else { return nil }
        return loadAll()[normalizedProviderID]
    }

    func save(_ entitlement: MarketplaceEntitlementRecord) {
        var records = loadAll()
        records[entitlement.providerID] = entitlement
        guard let data = try? JSONEncoder().encode(records) else { return }
        do {
            try KeychainManager.saveThrowing(
                data: data,
                for: storageKey,
                accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            )
        } catch {
            CrashReporter.record(error: error, context: "marketplace_entitlement_store")
        }
    }

    private func loadAll() -> [String: MarketplaceEntitlementRecord] {
        guard let data = KeychainManager.load(for: storageKey),
              let records = try? JSONDecoder().decode([String: MarketplaceEntitlementRecord].self, from: data) else {
            return [:]
        }
        return records
    }
}

@MainActor
private struct MarketplacePaymentConfirmationService: MarketplacePaymentConfirming {
    private struct RequestPayload: Encodable {
        let providerID: String
        let userID: String
        let paymentMode: String
        let transactionReference: String
        let paymentPayload: String
        let requestedAt: Date
    }

    private struct ResponsePayload: Decodable {
        let confirmed: Bool
        let receipt: String?
        let grantedAtMillis: Int64?
        let errorMessage: String?
    }

    func confirmPayment(
        for descriptor: MarketplaceProviderDescriptor,
        userID: String,
        authorization: MarketplaceAuthorizedPayment
    ) async throws -> MarketplaceEntitlementRecord {
        let request = RequestPayload(
            providerID: descriptor.normalizedProviderID,
            userID: userID,
            paymentMode: descriptor.paymentMode.rawValue,
            transactionReference: authorization.transactionReference,
            paymentPayload: authorization.paymentPayload,
            requestedAt: Date()
        )
        let body = try JSONEncoder().encode(request)
        let response: ResponsePayload = try await SecureHTTPClient.shared.request(
            endpoint: AppConfig.marketplacePaymentConfirmationURL.absoluteString,
            method: .post,
            body: body
        )

        guard response.confirmed else {
            throw MarketplacePaymentError.backendConfirmationFailed(
                response.errorMessage ?? "Marketplace payment confirmation was rejected."
            )
        }

        return MarketplaceEntitlementRecord(
            providerID: descriptor.normalizedProviderID,
            receipt: response.receipt ?? authorization.transactionReference,
            grantedAtMillis: response.grantedAtMillis ?? Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}

#if canImport(PassKit)
@MainActor
private final class MarketplaceApplePaySessionAuthorizer: NSObject, PKPaymentAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<MarketplacePaymentAuthorizationResult, Never>?
    private var pendingResult: MarketplacePaymentAuthorizationResult?

    func authorizePayment(
        for descriptor: MarketplaceProviderDescriptor,
        merchantID: String
    ) async -> MarketplacePaymentAuthorizationResult {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            return .unavailable("Apple Pay is unavailable on this device.")
        }
        guard let amount = descriptor.priceGBP, amount > 0 else {
            return .failed("A valid payment amount is required.")
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantID
        request.countryCode = RegionRuntime.activeConfiguration.currencyCode == "USD" ? "US" : "GB"
        request.currencyCode = RegionRuntime.activeConfiguration.currencyCode
        request.supportedNetworks = [.visa, .masterCard, .amex, .maestro]
        request.merchantCapabilities = [.threeDSecure]
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: descriptor.displayName, amount: NSDecimalNumber(decimal: amount))
        ]

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        let didPresent = await controller.present()
        guard didPresent else {
            return .failed("Apple Pay could not be presented.")
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        let paymentData = payment.token.paymentData
        let digest = SHA256.hash(data: paymentData)
        let transactionReference = Data(digest).base64EncodedString()
        pendingResult = .authorized(
            MarketplaceAuthorizedPayment(
                transactionReference: "applepay-\(transactionReference)",
                paymentPayload: paymentData.base64EncodedString(),
                finish: nil
            )
        )
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        let result = pendingResult ?? .cancelled
        let continuation = self.continuation
        self.continuation = nil
        self.pendingResult = nil
        controller.dismiss(completion: nil)
        continuation?.resume(returning: result)
    }
}

@MainActor
private struct MarketplaceApplePayAuthorizer: MarketplaceApplePayAuthorizing {
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
        guard let merchantID = AppConfig.applePayMerchantID else {
            return .unavailable("Apple Pay merchant configuration is missing.")
        }

        let sessionAuthorizer = MarketplaceApplePaySessionAuthorizer()
        return await sessionAuthorizer.authorizePayment(
            for: descriptor,
            merchantID: merchantID
        )
    }
}
#else
private struct MarketplaceApplePayAuthorizer: MarketplaceApplePayAuthorizing {
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
        .unavailable("Apple Pay is unavailable on this device.")
    }
}
#endif

#if canImport(StoreKit)
@MainActor
private struct MarketplaceStoreKitAuthorizer: MarketplaceStoreKitAuthorizing {
    func hasEntitlement(for descriptor: MarketplaceProviderDescriptor) async -> Bool {
        guard let productID = normalizedProductID(for: descriptor) else { return false }
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == productID {
                return true
            }
        }
        return false
    }

    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
        guard let productID = normalizedProductID(for: descriptor) else {
            return .unavailable("StoreKit product configuration is missing.")
        }

        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                return .unavailable("The requested StoreKit product is unavailable.")
            }

            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    return .authorized(
                        MarketplaceAuthorizedPayment(
                            transactionReference: "storekit-\(transaction.id)",
                            paymentPayload: "\(transaction.id)",
                            finish: {
                                await transaction.finish()
                            }
                        )
                    )
                case .unverified(_, let error):
                    return .unverified(error.localizedDescription)
                }
            @unknown default:
                return .failed("Unknown StoreKit purchase result.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restoreEntitlements() async -> [String] {
        var productIDs: [String] = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                productIDs.append(transaction.productID)
            }
        }
        return productIDs
    }

    private func normalizedProductID(for descriptor: MarketplaceProviderDescriptor) -> String? {
        let trimmed = descriptor.paymentProductID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
#else
private struct MarketplaceStoreKitAuthorizer: MarketplaceStoreKitAuthorizing {
    func hasEntitlement(for descriptor: MarketplaceProviderDescriptor) async -> Bool { false }
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
        .unavailable("StoreKit is unavailable on this device.")
    }
    func restoreEntitlements() async -> [String] { [] }
}
#endif

@MainActor
final class MarketplacePaymentCoordinator {
    static let shared = MarketplacePaymentCoordinator()

    private let applePayAuthorizer: any MarketplaceApplePayAuthorizing
    private let storeKitAuthorizer: any MarketplaceStoreKitAuthorizing
    private let confirmationService: any MarketplacePaymentConfirming
    private let entitlementStore: any MarketplaceEntitlementStoring
    private let nowProvider: @Sendable () -> Date

    private(set) var latestEvent: MarketplacePaymentEvent?
    private var hasRestoredEntitlements = false

    init(
        applePayAuthorizer: (any MarketplaceApplePayAuthorizing)? = nil,
        storeKitAuthorizer: (any MarketplaceStoreKitAuthorizing)? = nil,
        confirmationService: (any MarketplacePaymentConfirming)? = nil,
        entitlementStore: (any MarketplaceEntitlementStoring)? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.applePayAuthorizer = applePayAuthorizer ?? MarketplaceApplePayAuthorizer()
        self.storeKitAuthorizer = storeKitAuthorizer ?? MarketplaceStoreKitAuthorizer()
        self.confirmationService = confirmationService ?? MarketplacePaymentConfirmationService()
        self.entitlementStore = entitlementStore ?? MarketplaceEntitlementKeychainStore()
        self.nowProvider = nowProvider
    }

    func restoreEntitlementsIfNeeded() async {
        guard !hasRestoredEntitlements else { return }
        hasRestoredEntitlements = true

        let restoredProductIDs = await storeKitAuthorizer.restoreEntitlements()
        for productID in restoredProductIDs {
            let normalizedProviderID = productID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard entitlementStore.entitlement(for: normalizedProviderID) == nil else { continue }
            entitlementStore.save(
                MarketplaceEntitlementRecord(
                    providerID: normalizedProviderID,
                    receipt: "restored-\(productID)",
                    grantedAtMillis: Int64(nowProvider().timeIntervalSince1970 * 1000)
                )
            )
        }
    }

    func processServicePayment(
        for descriptor: MarketplaceProviderDescriptor,
        userID: String
    ) async -> MarketplacePaymentResult {
        await restoreEntitlementsIfNeeded()

        guard descriptor.requiresPayment else {
            return .notRequired
        }

        let providerID = descriptor.normalizedProviderID
        if let existingEntitlement = entitlementStore.entitlement(for: providerID) {
            emit(.succeeded(receipt: existingEntitlement.receipt))
            return .succeeded(existingEntitlement.receipt)
        }

        emit(.initiated(providerID: providerID))
        emit(.processing(providerID: providerID))

        switch descriptor.paymentMode {
        case .none:
            return .notRequired
        case .applePay:
            let authorization = await applePayAuthorizer.authorizePayment(for: descriptor)
            return await finalizeAuthorization(
                authorization,
                descriptor: descriptor,
                userID: userID
            )
        case .storeKit:
            if await storeKitAuthorizer.hasEntitlement(for: descriptor) {
                let restoredReceipt = "restored-\(descriptor.paymentProductID ?? providerID)"
                let entitlement = MarketplaceEntitlementRecord(
                    providerID: providerID,
                    receipt: restoredReceipt,
                    grantedAtMillis: Int64(nowProvider().timeIntervalSince1970 * 1000)
                )
                entitlementStore.save(entitlement)
                emit(.succeeded(receipt: restoredReceipt))
                return .succeeded(restoredReceipt)
            }

            let authorization = await storeKitAuthorizer.authorizePayment(for: descriptor)
            return await finalizeAuthorization(
                authorization,
                descriptor: descriptor,
                userID: userID
            )
        }
    }

    private func finalizeAuthorization(
        _ authorization: MarketplacePaymentAuthorizationResult,
        descriptor: MarketplaceProviderDescriptor,
        userID: String
    ) async -> MarketplacePaymentResult {
        switch authorization {
        case .authorized(let authorizedPayment):
            emit(.pendingVerification(providerID: descriptor.normalizedProviderID))
            do {
                let entitlement = try await confirmationService.confirmPayment(
                    for: descriptor,
                    userID: userID,
                    authorization: authorizedPayment
                )
                entitlementStore.save(entitlement)
                if let finish = authorizedPayment.finish {
                    await finish()
                }
                emit(.succeeded(receipt: entitlement.receipt))
                return .succeeded(entitlement.receipt)
            } catch let error as MarketplacePaymentError {
                emit(.failed(error))
                return .failed(error)
            } catch {
                let wrapped = MarketplacePaymentError.backendConfirmationFailed(error.localizedDescription)
                emit(.failed(wrapped))
                return .failed(wrapped)
            }
        case .pending:
            emit(.pendingVerification(providerID: descriptor.normalizedProviderID))
            return .pending
        case .cancelled:
            emit(.cancelled)
            return .cancelled
        case .unavailable(let reason):
            emit(.failed(.unavailable(reason)))
            return .unavailable
        case .unverified(let reason):
            let error = MarketplacePaymentError.unverifiedReceipt(reason)
            emit(.failed(error))
            return .failed(error)
        case .failed(let reason):
            let error = MarketplacePaymentError.paymentFailed(reason)
            emit(.failed(error))
            return .failed(error)
        }
    }

    private func emit(_ event: MarketplacePaymentEvent) {
        latestEvent = event

        var properties: [String: String] = [:]
        switch event {
        case .initiated(let providerID):
            properties["providerID"] = providerID
            TelemetryStore.shared.record(name: "marketplace_payment_initiated", level: .info, properties: properties)
        case .processing(let providerID):
            properties["providerID"] = providerID
            TelemetryStore.shared.record(name: "marketplace_payment_processing", level: .info, properties: properties)
        case .pendingVerification(let providerID):
            properties["providerID"] = providerID
            TelemetryStore.shared.record(name: "marketplace_payment_pending_verification", level: .info, properties: properties)
        case .succeeded(let receipt):
            properties["receiptPrefix"] = String(receipt.prefix(18))
            TelemetryStore.shared.record(name: "marketplace_payment_succeeded", level: .info, properties: properties)
        case .failed(let error):
            properties["error"] = error.localizedDescription
            TelemetryStore.shared.record(name: "marketplace_payment_failed", level: .error, properties: properties)
        case .cancelled:
            TelemetryStore.shared.record(name: "marketplace_payment_cancelled", level: .info)
        }
    }
}
