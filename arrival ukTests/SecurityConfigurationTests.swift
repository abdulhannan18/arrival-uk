import XCTest
@testable import arrival_uk

@MainActor
final class SecurityConfigurationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppConfig.resetTestingOverrides()
        MarketplaceIdentityTokenService.testingSigningKeyProvider = nil
        WalletShareAuthorizationService.testingSigningKeyProvider = nil
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        WalletShareAuthorizationService.testingSigningKeyProvider = nil
        MarketplaceIdentityTokenService.testingSigningKeyProvider = nil
        AppConfig.resetTestingOverrides()
        super.tearDown()
    }

    func testProductionCollaborationOverrideRejectsInsecureWebSocketURL() {
        AppConfig.setTestingOverride("production", for: "ARRIVAL_APP_ENV")
        AppConfig.setTestingOverride("https://api.arrivaluk.app", for: "ARRIVAL_API_BASE_URL")
        AppConfig.setTestingOverride("ws://evil.example/socket", for: "ARRIVAL_COLLAB_WS_URL")

        let resolved = AppConfig.collaborationWebSocketURL

        XCTAssertEqual(resolved?.scheme, "wss")
        XCTAssertEqual(resolved?.host, "api.arrivaluk.app")
    }

    func testDevelopmentCollaborationOverrideAllowsInsecureWebSocketURL() {
        AppConfig.setTestingOverride("development", for: "ARRIVAL_APP_ENV")
        AppConfig.setTestingOverride("ws://localhost:8080/realtime", for: "ARRIVAL_COLLAB_WS_URL")

        let resolved = AppConfig.collaborationWebSocketURL

        XCTAssertEqual(resolved?.absoluteString, "ws://localhost:8080/realtime")
    }

    func testMarketplaceProviderRejectsUnallowlistedHostOutsideDevelopment() async {
        AppConfig.setTestingOverride("production", for: "ARRIVAL_APP_ENV")
        AppConfig.setTestingOverride("trusted.arrivaluk.app", for: "ARRIVAL_ALLOWED_MARKETPLACE_HOSTS")

        let descriptor = MarketplaceProviderDescriptor(
            providerID: "provider",
            displayName: "Provider",
            serviceType: .banking,
            ctaTitle: "Continue",
            requiredDocs: [],
            requestedFields: [.fullName],
            onboardingURL: URL(string: "https://evil.example/start"),
            universalVerifyPath: nil,
            completionTaskID: nil,
            completionCategoryID: nil,
            paymentMode: .none,
            paymentProductID: nil,
            priceGBP: nil,
            discoveryTag: nil
        )

        let provider = MarketplaceNetworkServiceProvider(descriptor: descriptor)
        let context = MarketplaceOnboardingContext(
            providerID: descriptor.normalizedProviderID,
            identityToken: "signed-token",
            journeyID: "journey-1",
            requestedFields: [.fullName]
        )

        do {
            _ = try await provider.initiateOnboarding(context: context)
            XCTFail("Expected unallowlisted marketplace provider host to be rejected")
        } catch let error as MarketplaceProviderError {
            XCTAssertEqual(error, .unavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testIdentityTokenIssuanceFailsWhenSigningKeyUnavailable() {
        MarketplaceIdentityTokenService.testingSigningKeyProvider = { nil }

        let token = MarketplaceIdentityTokenService.issueTemporaryToken(
            providerID: "giffgaff_sim",
            userID: "student-123",
            requestedFields: [.fullName]
        )

        XCTAssertNil(token)
    }

    func testWalletShareTokenIssuanceFailsWhenSigningKeyUnavailable() {
        WalletShareAuthorizationService.testingSigningKeyProvider = { nil }

        let token = WalletShareAuthorizationService.issueToken(
            documentID: UUID(),
            issuedBy: "mentor-user",
            ttlSeconds: 60,
            allowsSensitiveFields: false
        )

        XCTAssertNil(token)
    }

    func testSecureHTTPClientInjectsAuthorizationHeader() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{}".utf8))
        }

        let client = SecureHTTPClient(
            configuration: configuration,
            authorizer: FixedAuthorizationHeaderProvider(headers: ["Authorization": "Bearer test-token"])
        )

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await client.request(endpoint: "https://api.arrivaluk.app/test")
    }

    func testSecureHTTPClientDoesNotOverrideExplicitAuthorizationHeader() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer explicit")
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{}".utf8))
        }

        let client = SecureHTTPClient(
            configuration: configuration,
            authorizer: FixedAuthorizationHeaderProvider(headers: ["Authorization": "Bearer injected"])
        )

        _ = try await client.execute(
            endpoint: "https://api.arrivaluk.app/test",
            headers: ["Authorization": "Bearer explicit"]
        )
    }

    func testSecureHTTPClientRejectsInsecureScheme() async {
        let client = SecureHTTPClient(
            configuration: .ephemeral,
            authorizer: FixedAuthorizationHeaderProvider(headers: [:])
        )

        do {
            _ = try await client.execute(endpoint: "http://api.arrivaluk.app/test")
            XCTFail("Expected insecure http scheme to be rejected")
        } catch let error as SecureHTTPClientError {
            switch error {
            case .insecureScheme:
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct FixedAuthorizationHeaderProvider: SecureHTTPRequestAuthorizing {
    let headers: [String: String]

    func authorizationHeaders(for url: URL) async throws -> [String: String] {
        headers
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
