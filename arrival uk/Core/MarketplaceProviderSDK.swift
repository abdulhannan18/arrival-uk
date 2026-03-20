import Foundation

enum MarketplaceServiceType: String, Codable, Hashable, Sendable {
    case banking
    case sim
    case housing
    case unknown

    init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "banking", "bank", "finance":
            self = .banking
        case "sim", "mobile", "telecom":
            self = .sim
        case "housing", "rent", "deposit":
            self = .housing
        default:
            self = .unknown
        }
    }
}

enum MarketplacePaymentMode: String, Codable, Hashable, Sendable {
    case none
    case applePay = "apple_pay"
    case storeKit = "storekit"
}

enum MarketplaceIdentityField: String, Codable, Hashable, Sendable {
    case fullName = "full_name"
    case ukAddress = "uk_address"
    case passportScan = "passport_scan"
    case visaReference = "visa_reference"
}

struct MarketplaceProviderDescriptor: Codable, Hashable, Sendable, Identifiable {
    let providerID: String
    let displayName: String
    let serviceType: MarketplaceServiceType
    let ctaTitle: String
    let requiredDocs: [WalletRequiredDocument]
    let requestedFields: [MarketplaceIdentityField]
    let onboardingURL: URL?
    let universalVerifyPath: String?
    let completionTaskID: String?
    let completionCategoryID: String?
    let paymentMode: MarketplacePaymentMode
    let paymentProductID: String?
    let priceGBP: Decimal?
    let discoveryTag: String?
    let supportedRegions: [ArrivalRegion]

    var id: String { providerID }

    var normalizedProviderID: String {
        providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var requiresPayment: Bool {
        paymentMode != .none
    }

    init(
        providerID: String,
        displayName: String,
        serviceType: MarketplaceServiceType,
        ctaTitle: String,
        requiredDocs: [WalletRequiredDocument],
        requestedFields: [MarketplaceIdentityField],
        onboardingURL: URL?,
        universalVerifyPath: String?,
        completionTaskID: String?,
        completionCategoryID: String?,
        paymentMode: MarketplacePaymentMode,
        paymentProductID: String?,
        priceGBP: Decimal?,
        discoveryTag: String?,
        supportedRegions: [ArrivalRegion] = []
    ) {
        self.providerID = providerID
        self.displayName = displayName
        self.serviceType = serviceType
        self.ctaTitle = ctaTitle
        self.requiredDocs = requiredDocs
        self.requestedFields = requestedFields
        self.onboardingURL = onboardingURL
        self.universalVerifyPath = universalVerifyPath
        self.completionTaskID = completionTaskID
        self.completionCategoryID = completionCategoryID
        self.paymentMode = paymentMode
        self.paymentProductID = paymentProductID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.priceGBP = priceGBP
        self.discoveryTag = discoveryTag

        var deduplicated: [ArrivalRegion] = []
        for region in supportedRegions where !deduplicated.contains(region) {
            deduplicated.append(region)
        }
        self.supportedRegions = deduplicated
    }
}

struct OnboardingResult: Hashable, Sendable {
    let providerID: String
    let status: String
    let completionToken: String
    let deepLinkURL: URL?
    let completedTaskID: String?
    let completedCategoryID: String?
}

struct MarketplaceOnboardingContext: Sendable {
    let providerID: String
    let identityToken: String
    let journeyID: String
    let requestedFields: [MarketplaceIdentityField]
}

enum MarketplaceProviderError: LocalizedError {
    case unavailable
    case timedOut
    case malformedResponse
    case paymentFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The selected provider is currently unavailable."
        case .timedOut:
            return "The provider request timed out."
        case .malformedResponse:
            return "The provider response was invalid."
        case .paymentFailed:
            return "Payment could not be completed."
        }
    }
}

protocol ServiceProvider: Sendable {
    var providerID: String { get }
    var requiredDocs: [WalletRequiredDocument] { get }
    func initiateOnboarding(context: MarketplaceOnboardingContext) async throws -> OnboardingResult
}

struct MarketplaceNetworkServiceProvider: ServiceProvider {
    let providerID: String
    let requiredDocs: [WalletRequiredDocument]
    private let descriptor: MarketplaceProviderDescriptor

    init(descriptor: MarketplaceProviderDescriptor) {
        self.providerID = descriptor.providerID
        self.requiredDocs = descriptor.requiredDocs
        self.descriptor = descriptor
    }

    func initiateOnboarding(context: MarketplaceOnboardingContext) async throws -> OnboardingResult {
        guard let endpoint = descriptor.onboardingURL,
              endpoint.scheme?.lowercased() == "https",
              let host = endpoint.host,
              AppConfig.isAllowedMarketplaceProviderHost(host) else {
            throw MarketplaceProviderError.unavailable
        }

        nonisolated struct RequestPayload: Encodable {
            let identityToken: String
            let journeyID: String
            let providerID: String
            let requestedFields: [String]
        }
        nonisolated struct ResponsePayload: Decodable {
            let status: String?
            let completionToken: String?
            let deepLink: String?
        }

        let payload = RequestPayload(
            identityToken: context.identityToken,
            journeyID: context.journeyID,
            providerID: context.providerID,
            requestedFields: context.requestedFields.map(\.rawValue)
        )
        let body = try JSONEncoder().encode(payload)
        let response: ResponsePayload = try await withTimeout(seconds: 8) {
            try await SecureHTTPClient.shared.request(
                endpoint: endpoint.absoluteString,
                method: .post,
                body: body
            )
        }

        let completionToken = response.completionToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !completionToken.isEmpty else {
            throw MarketplaceProviderError.malformedResponse
        }

        let normalizedStatus = response.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "started"
        let deepLinkURL = response.deepLink.flatMap { URL(string: $0) }
        return OnboardingResult(
            providerID: providerID,
            status: normalizedStatus,
            completionToken: completionToken,
            deepLinkURL: deepLinkURL ?? descriptor.onboardingURL,
            completedTaskID: descriptor.completionTaskID,
            completedCategoryID: descriptor.completionCategoryID
        )
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(max(seconds, 0.1)))
                throw MarketplaceProviderError.timedOut
            }

            guard let first = try await group.next() else {
                throw MarketplaceProviderError.unavailable
            }
            group.cancelAll()
            return first
        }
    }
}

enum ServiceProviderFactory {
    static func resolveProvider(
        descriptor: MarketplaceProviderDescriptor
    ) -> ServiceProvider {
        MarketplaceNetworkServiceProvider(descriptor: descriptor)
    }
}
