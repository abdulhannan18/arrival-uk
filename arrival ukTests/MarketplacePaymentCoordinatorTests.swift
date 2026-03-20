import XCTest
@testable import arrival_uk

@MainActor
final class MarketplacePaymentCoordinatorTests: XCTestCase {
    private final class EntitlementStoreState: @unchecked Sendable {
        var records: [String: MarketplaceEntitlementRecord] = [:]
        var saveCount = 0
    }

    private final class StoreKitState: @unchecked Sendable {
        var hasEntitlementCalls = 0
        var authorizeCalls = 0
        var restoreCalls = 0
    }

    private final class ConfirmationState: @unchecked Sendable {
        var callCount = 0
        var eventLog: [String] = []
    }

    private final class FinishState: @unchecked Sendable {
        var didFinish = false
        var eventLog: [String] = []
    }

    @MainActor
    private struct ScriptedEntitlementStore: MarketplaceEntitlementStoring {
        let state: EntitlementStoreState

        func entitlement(for providerID: String) -> MarketplaceEntitlementRecord? {
            state.records[providerID]
        }

        func save(_ entitlement: MarketplaceEntitlementRecord) {
            state.saveCount += 1
            state.records[entitlement.providerID] = entitlement
        }
    }

    @MainActor
    private struct ScriptedApplePayAuthorizer: MarketplaceApplePayAuthorizing {
        let result: MarketplacePaymentAuthorizationResult

        func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
            result
        }
    }

    @MainActor
    private struct ScriptedStoreKitAuthorizer: MarketplaceStoreKitAuthorizing {
        let state: StoreKitState
        let hasEntitlementResult: Bool
        let authorizationResult: MarketplacePaymentAuthorizationResult
        let restoredEntitlementsResult: [String]

        func hasEntitlement(for descriptor: MarketplaceProviderDescriptor) async -> Bool {
            state.hasEntitlementCalls += 1
            return hasEntitlementResult
        }

        func authorizePayment(for descriptor: MarketplaceProviderDescriptor) async -> MarketplacePaymentAuthorizationResult {
            state.authorizeCalls += 1
            return authorizationResult
        }

        func restoreEntitlements() async -> [String] {
            state.restoreCalls += 1
            return restoredEntitlementsResult
        }
    }

    @MainActor
    private struct ScriptedConfirmationService: MarketplacePaymentConfirming {
        let state: ConfirmationState
        let handler: @Sendable (
            MarketplaceProviderDescriptor,
            String,
            MarketplaceAuthorizedPayment
        ) async throws -> MarketplaceEntitlementRecord

        func confirmPayment(
            for descriptor: MarketplaceProviderDescriptor,
            userID: String,
            authorization: MarketplaceAuthorizedPayment
        ) async throws -> MarketplaceEntitlementRecord {
            state.callCount += 1
            return try await handler(descriptor, userID, authorization)
        }
    }

    private enum TestError: LocalizedError {
        case confirmationRejected

        var errorDescription: String? {
            switch self {
            case .confirmationRejected:
                return "confirmation_rejected"
            }
        }
    }

    private func makeDescriptor(
        providerID: String = "bank_provider",
        paymentMode: MarketplacePaymentMode = .storeKit,
        paymentProductID: String? = "com.arrival.test.provider",
        priceGBP: Decimal? = 4.99
    ) -> MarketplaceProviderDescriptor {
        MarketplaceProviderDescriptor(
            providerID: providerID,
            displayName: "Bank Provider",
            serviceType: .banking,
            ctaTitle: "Continue",
            requiredDocs: [],
            requestedFields: [.fullName],
            onboardingURL: URL(string: "https://example.com/onboarding"),
            universalVerifyPath: nil,
            completionTaskID: nil,
            completionCategoryID: nil,
            paymentMode: paymentMode,
            paymentProductID: paymentProductID,
            priceGBP: priceGBP,
            discoveryTag: nil
        )
    }

    private func makeCoordinator(
        storeState: EntitlementStoreState = EntitlementStoreState(),
        storeKitState: StoreKitState = StoreKitState(),
        confirmationState: ConfirmationState = ConfirmationState(),
        storeKitResult: MarketplacePaymentAuthorizationResult,
        hasEntitlement: Bool = false,
        restoredEntitlements: [String] = [],
        confirmationHandler: @escaping @Sendable (
            MarketplaceProviderDescriptor,
            String,
            MarketplaceAuthorizedPayment
        ) async throws -> MarketplaceEntitlementRecord = { descriptor, _, authorization in
            MarketplaceEntitlementRecord(
                providerID: descriptor.normalizedProviderID,
                receipt: authorization.transactionReference,
                grantedAtMillis: 1_742_473_600_000
            )
        }
    ) -> (
        coordinator: MarketplacePaymentCoordinator,
        storeState: EntitlementStoreState,
        storeKitState: StoreKitState,
        confirmationState: ConfirmationState
    ) {
        let coordinator = MarketplacePaymentCoordinator(
            applePayAuthorizer: ScriptedApplePayAuthorizer(result: .unavailable("unused")),
            storeKitAuthorizer: ScriptedStoreKitAuthorizer(
                state: storeKitState,
                hasEntitlementResult: hasEntitlement,
                authorizationResult: storeKitResult,
                restoredEntitlementsResult: restoredEntitlements
            ),
            confirmationService: ScriptedConfirmationService(
                state: confirmationState,
                handler: confirmationHandler
            ),
            entitlementStore: ScriptedEntitlementStore(state: storeState),
            nowProvider: { Date(timeIntervalSince1970: 1_742_473_600) }
        )

        return (coordinator, storeState, storeKitState, confirmationState)
    }

    func testUnverifiedReceiptDoesNotGrantEntitlement() async {
        let harness = makeCoordinator(
            storeKitResult: .unverified("receipt_not_verified")
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        guard case .failed(let error) = result else {
            return XCTFail("Expected unverified receipt failure.")
        }
        XCTAssertEqual(error, .unverifiedReceipt("receipt_not_verified"))
        XCTAssertEqual(harness.confirmationState.callCount, 0)
        XCTAssertEqual(harness.storeState.saveCount, 0)
        XCTAssertTrue(harness.storeState.records.isEmpty)
        XCTAssertEqual(harness.coordinator.latestEvent, .failed(.unverifiedReceipt("receipt_not_verified")))
    }

    func testEntitlementGrantedOnlyAfterBackendConfirmation() async {
        let confirmationState = ConfirmationState()
        let finishState = FinishState()
        let authorizedPayment = MarketplaceAuthorizedPayment(
            transactionReference: "storekit-987654321",
            paymentPayload: "987654321",
            finish: {
                finishState.didFinish = true
                confirmationState.eventLog.append("finish")
            }
        )
        let harness = makeCoordinator(
            confirmationState: confirmationState,
            storeKitResult: .authorized(authorizedPayment),
            confirmationHandler: { _, userID, authorization in
                XCTAssertEqual(userID, "user_123")
                confirmationState.eventLog.append("confirm")
                return MarketplaceEntitlementRecord(
                    providerID: "bank_provider",
                    receipt: authorization.transactionReference,
                    grantedAtMillis: 1_742_473_600_000
                )
            }
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        XCTAssertEqual(result, .succeeded("storekit-987654321"))
        XCTAssertEqual(harness.confirmationState.callCount, 1)
        XCTAssertEqual(harness.storeState.saveCount, 1)
        XCTAssertEqual(harness.storeState.records["bank_provider"]?.receipt, "storekit-987654321")
        XCTAssertTrue(finishState.didFinish)
        XCTAssertEqual(confirmationState.eventLog, ["confirm", "finish"])
    }

    func testTransactionFinishedOnlyAfterSuccessfulGrant() async {
        let finishState = FinishState()
        let harness = makeCoordinator(
            storeKitResult: .authorized(
                MarketplaceAuthorizedPayment(
                    transactionReference: "storekit-123",
                    paymentPayload: "123",
                    finish: {
                        finishState.didFinish = true
                        finishState.eventLog.append("finish")
                    }
                )
            ),
            confirmationHandler: { _, _, _ in
                throw TestError.confirmationRejected
            }
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        guard case .failed(let error) = result else {
            return XCTFail("Expected backend confirmation failure.")
        }
        XCTAssertEqual(error, .backendConfirmationFailed(TestError.confirmationRejected.localizedDescription))
        XCTAssertFalse(finishState.didFinish)
        XCTAssertEqual(harness.storeState.saveCount, 0)
    }

    func testDuplicatePurchaseBlockedIfEntitlementExists() async {
        let storeState = EntitlementStoreState()
        storeState.records["bank_provider"] = MarketplaceEntitlementRecord(
            providerID: "bank_provider",
            receipt: "existing-receipt",
            grantedAtMillis: 1_742_473_500_000
        )
        let storeKitState = StoreKitState()
        let confirmationState = ConfirmationState()
        let harness = makeCoordinator(
            storeState: storeState,
            storeKitState: storeKitState,
            confirmationState: confirmationState,
            storeKitResult: .failed("should_not_run")
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        XCTAssertEqual(result, .succeeded("existing-receipt"))
        XCTAssertEqual(storeKitState.authorizeCalls, 0)
        XCTAssertEqual(confirmationState.callCount, 0)
        XCTAssertEqual(storeState.saveCount, 0)
    }

    func testPendingPurchaseDoesNotGrantOrDeny() async {
        let harness = makeCoordinator(
            storeKitResult: .pending
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        XCTAssertEqual(result, .pending)
        XCTAssertEqual(harness.confirmationState.callCount, 0)
        XCTAssertEqual(harness.storeState.saveCount, 0)
        XCTAssertEqual(harness.coordinator.latestEvent, .pendingVerification(providerID: "bank_provider"))
    }

    func testUserCancelledDoesNotTriggerErrorState() async {
        let harness = makeCoordinator(
            storeKitResult: .cancelled
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(harness.confirmationState.callCount, 0)
        XCTAssertEqual(harness.storeState.saveCount, 0)
        XCTAssertEqual(harness.coordinator.latestEvent, .cancelled)
    }

    func testPaymentFailureEmitsCorrectErrorType() async {
        let harness = makeCoordinator(
            storeKitResult: .failed("processor_down")
        )

        let result = await harness.coordinator.processServicePayment(
            for: makeDescriptor(),
            userID: "user_123"
        )

        guard case .failed(let error) = result else {
            return XCTFail("Expected payment failure result.")
        }
        XCTAssertEqual(error, .paymentFailed("processor_down"))
        XCTAssertEqual(harness.coordinator.latestEvent, .failed(.paymentFailed("processor_down")))
    }
}
