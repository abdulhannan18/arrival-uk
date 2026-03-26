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
    case entitlementPersistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason),
             .unverifiedReceipt(let reason),
             .backendConfirmationFailed(let reason),
             .paymentFailed(let reason),
             .entitlementPersistenceFailed(let reason):
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
    let finalizeAuthorization: (@MainActor @Sendable (MarketplacePaymentAuthorizationDisposition) -> Void)?

    init(
        transactionReference: String,
        paymentPayload: String,
        finish: (@Sendable () async -> Void)? = nil,
        finalizeAuthorization: (@MainActor @Sendable (MarketplacePaymentAuthorizationDisposition) -> Void)? = nil
    ) {
        self.transactionReference = transactionReference
        self.paymentPayload = paymentPayload
        self.finish = finish
        self.finalizeAuthorization = finalizeAuthorization
    }
}

nonisolated enum MarketplacePaymentAuthorizationResult: Sendable {
    case authorized(MarketplaceAuthorizedPayment)
    case pending
    case cancelled
    case unavailable(String)
    case unverified(String)
    case failed(String)
}

nonisolated enum MarketplacePaymentAuthorizationDisposition: Sendable {
    case success
    case failure(String)
}

nonisolated struct MarketplaceEntitlementRecord: Codable, Hashable, Sendable {
    let providerID: String
    let receipt: String
    let grantedAtMillis: Int64
}

nonisolated struct MarketplaceApplePayRequestContext: Equatable, Sendable {
    let countryCode: String
    let currencyCode: String

    static func forDescriptor(_ descriptor: MarketplaceProviderDescriptor) -> MarketplaceApplePayRequestContext {
        // Apple Pay currently prices marketplace add-ons in GBP only. Keep the request
        // contract aligned with `priceGBP` until multi-currency pricing is introduced.
        let _ = descriptor
        return MarketplaceApplePayRequestContext(
            countryCode: "GB",
            currencyCode: "GBP"
        )
    }
}

@MainActor
protocol MarketplaceEntitlementStoring: Sendable {
    func entitlement(for providerID: String) -> MarketplaceEntitlementRecord?
    func save(_ entitlement: MarketplaceEntitlementRecord) throws
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

    func save(_ entitlement: MarketplaceEntitlementRecord) throws {
        var records = loadAll()
        records[entitlement.providerID] = entitlement
        guard let data = try? JSONEncoder().encode(records) else {
            throw MarketplacePaymentError.entitlementPersistenceFailed(
                "Marketplace entitlement could not be encoded for secure storage."
            )
        }
        do {
            try KeychainManager.saveThrowing(
                data: data,
                for: storageKey,
                accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            )
        } catch {
            CrashReporter.record(error: error, context: "marketplace_entitlement_store")
            throw MarketplacePaymentError.entitlementPersistenceFailed(
                "Marketplace entitlement could not be persisted securely."
            )
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
    private var authorizationCompletion: ((PKPaymentAuthorizationResult) -> Void)?
    private var hasResolvedAuthorization = false

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
        let paymentContext = MarketplaceApplePayRequestContext.forDescriptor(descriptor)
        request.merchantIdentifier = merchantID
        request.countryCode = paymentContext.countryCode
        request.currencyCode = paymentContext.currencyCode
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
            self.hasResolvedAuthorization = false
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
        authorizationCompletion = completion
        hasResolvedAuthorization = true
        continuation?.resume(
            returning: .authorized(
                MarketplaceAuthorizedPayment(
                    transactionReference: "applepay-\(transactionReference)",
                    paymentPayload: paymentData.base64EncodedString(),
                    finish: nil,
                    finalizeAuthorization: { [weak self] disposition in
                        self?.completeAuthorization(disposition)
                    }
                )
            )
        )
        continuation = nil
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        if !hasResolvedAuthorization {
            continuation?.resume(returning: .cancelled)
            continuation = nil
        }
        authorizationCompletion = nil
        hasResolvedAuthorization = false
        controller.dismiss(completion: nil)
    }

    private func completeAuthorization(_ disposition: MarketplacePaymentAuthorizationDisposition) {
        guard let authorizationCompletion else { return }
        self.authorizationCompletion = nil

        switch disposition {
        case .success:
            authorizationCompletion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        case .failure(let message):
            let error = NSError(
                domain: "MarketplaceApplePayAuthorization",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            authorizationCompletion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
        }
    }
}

@MainActor
private struct MarketplaceApplePayAuthorizer: MarketplaceApplePayAuthorizing {
    func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
        let sessionAuthorizer = MarketplaceApplePaySessionAuthorizer()
        return await sessionAuthorizer.authorizePayment(
            for: descriptor,
            merchantID: AppConfig.applePayMerchantID
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
            do {
                try entitlementStore.save(
                    MarketplaceEntitlementRecord(
                        providerID: normalizedProviderID,
                        receipt: "restored-\(productID)",
                        grantedAtMillis: Int64(nowProvider().timeIntervalSince1970 * 1000)
                    )
                )
            } catch {
                CrashReporter.record(error: error, context: "marketplace_restore_entitlement")
            }
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
        if let existingEntitlement = existingEntitlement(for: descriptor) {
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
                do {
                    try entitlementStore.save(entitlement)
                    emit(.succeeded(receipt: restoredReceipt))
                    return .succeeded(restoredReceipt)
                } catch let error as MarketplacePaymentError {
                    emit(.failed(error))
                    return .failed(error)
                } catch {
                    let wrapped = MarketplacePaymentError.entitlementPersistenceFailed(error.localizedDescription)
                    emit(.failed(wrapped))
                    return .failed(wrapped)
                }
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
                try entitlementStore.save(entitlement)
                authorizedPayment.finalizeAuthorization?(.success)
                if let finish = authorizedPayment.finish {
                    await finish()
                }
                emit(.succeeded(receipt: entitlement.receipt))
                return .succeeded(entitlement.receipt)
            } catch let error as MarketplacePaymentError {
                authorizedPayment.finalizeAuthorization?(.failure(error.localizedDescription))
                emit(.failed(error))
                return .failed(error)
            } catch {
                let wrapped = MarketplacePaymentError.backendConfirmationFailed(error.localizedDescription)
                authorizedPayment.finalizeAuthorization?(.failure(wrapped.localizedDescription))
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

    private func existingEntitlement(for descriptor: MarketplaceProviderDescriptor) -> MarketplaceEntitlementRecord? {
        if let direct = entitlementStore.entitlement(for: descriptor.normalizedProviderID) {
            return direct
        }

        let normalizedProductID = descriptor.paymentProductID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let normalizedProductID, !normalizedProductID.isEmpty else {
            return nil
        }

        return entitlementStore.entitlement(for: normalizedProductID)
    }
}
