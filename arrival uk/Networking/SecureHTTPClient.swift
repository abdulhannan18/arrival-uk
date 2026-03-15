import Foundation
import CryptoKit
import Security

/// Minimal, production-safe networking client that enforces HTTPS by default.
/// Requires iOS 17.0+
@available(iOS 17.0, *)
final class SecureHTTPClient: NSObject, URLSessionDelegate {
    static let shared = SecureHTTPClient()

    private let sessionConfiguration: URLSessionConfiguration
    private lazy var session: URLSession = {
        URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )
    }()

    init(configuration: URLSessionConfiguration = .default) {
        let config = (configuration.copy() as? URLSessionConfiguration) ?? .default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        self.sessionConfiguration = config
        super.init()
    }

    func request<Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> Response {
        guard let url = URL(string: endpoint) else {
            throw SecureHTTPClientError.invalidURL(endpoint)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw SecureHTTPClientError.insecureScheme(url.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("arrival-uk-ios/1.0", forHTTPHeaderField: "User-Agent")

        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SecureHTTPClientError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SecureHTTPClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw SecureHTTPClientError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SecureHTTPClientError.decoding(error)
        }
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard SecTrustEvaluateWithError(trust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        let pinnedHashes = AppConfig.networkTrust.pinnedHashes(for: host)
        let shouldEnforce = AppConfig.networkTrust.enforcePinning

        if pinnedHashes.isEmpty {
            let hostIsExplicitlyAllowed = AppConfig.networkTrust.isExplicitlyAllowedUnpinnedHost(host)
            if shouldEnforce, !(hostIsExplicitlyAllowed || AppConfig.networkTrust.allowUnpinnedHosts) {
                completionHandler(.cancelAuthenticationChallenge, nil)
            } else {
                completionHandler(.useCredential, URLCredential(trust: trust))
            }
            return
        }

        let observedHashes = Self.subjectPublicKeyInfoSHA256Hashes(from: trust)
        if pinnedHashes.isDisjoint(with: observedHashes) {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private static func subjectPublicKeyInfoSHA256Hashes(from trust: SecTrust) -> Set<String> {
        var hashes: Set<String> = []
        guard let certificateChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return hashes
        }

        for certificate in certificateChain {
            let certificateData = SecCertificateCopyData(certificate) as Data
            guard let spkiData = subjectPublicKeyInfoData(fromCertificateData: certificateData) else {
                continue
            }
            let digest = SHA256.hash(data: spkiData)
            hashes.insert(Data(digest).base64EncodedString())
        }

        return hashes
    }

    private static func subjectPublicKeyInfoData(fromCertificateData certificateData: Data) -> Data? {
        guard let topLevel = derElement(at: 0, in: certificateData),
              topLevel.tag == 0x30,
              let topLevelValueRange = derValueRange(for: topLevel),
              let tbsCertificate = derElement(at: topLevelValueRange.lowerBound, in: certificateData),
              tbsCertificate.tag == 0x30,
              let tbsRange = derValueRange(for: tbsCertificate)
        else {
            return nil
        }

        var cursor = tbsRange.lowerBound

        // Optional [0] EXPLICIT version (v2/v3 certificates).
        if let maybeVersion = derElement(at: cursor, in: certificateData), maybeVersion.tag == 0xA0 {
            cursor = maybeVersion.range.upperBound
        }

        // serialNumber, signature, issuer, validity, subject
        for _ in 0..<5 {
            guard let element = derElement(at: cursor, in: certificateData) else { return nil }
            cursor = element.range.upperBound
        }

        guard let subjectPublicKeyInfo = derElement(at: cursor, in: certificateData) else {
            return nil
        }

        return certificateData.subdata(in: subjectPublicKeyInfo.range)
    }

    private struct DERElement {
        let tag: UInt8
        let range: Range<Int>
        let headerLength: Int
    }

    private static func derElement(at offset: Int, in data: Data) -> DERElement? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        let tag = data[offset]
        let lengthByte = Int(data[offset + 1])

        if (lengthByte & 0x80) == 0 {
            let contentLength = lengthByte
            let headerLength = 2
            let totalLength = headerLength + contentLength
            let end = offset + totalLength
            guard end <= data.count else { return nil }
            return DERElement(tag: tag, range: offset..<end, headerLength: headerLength)
        }

        let lengthByteCount = lengthByte & 0x7F
        guard lengthByteCount > 0, lengthByteCount <= 4 else { return nil }
        guard offset + 2 + lengthByteCount <= data.count else { return nil }

        var contentLength = 0
        for index in 0..<lengthByteCount {
            contentLength = (contentLength << 8) | Int(data[offset + 2 + index])
        }

        let headerLength = 2 + lengthByteCount
        let totalLength = headerLength + contentLength
        let end = offset + totalLength
        guard end <= data.count else { return nil }
        return DERElement(tag: tag, range: offset..<end, headerLength: headerLength)
    }

    private static func derValueRange(for element: DERElement) -> Range<Int>? {
        let valueStart = element.range.lowerBound + element.headerLength
        guard valueStart <= element.range.upperBound else { return nil }
        return valueStart..<element.range.upperBound
    }
}

@available(iOS 17.0, *)
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

@available(iOS 17.0, *)
enum SecureHTTPClientError: LocalizedError {
    case invalidURL(String)
    case insecureScheme(String)
    case invalidResponse
    case httpStatus(Int)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let endpoint):
            return "Invalid URL: \(endpoint)"
        case .insecureScheme(let endpoint):
            return "Insecure URL scheme is not allowed: \(endpoint)"
        case .invalidResponse:
            return "Server returned an invalid response."
        case .httpStatus(let statusCode):
            return "Server request failed with status \(statusCode)."
        case .transport:
            return "Network request failed. Check your connection and try again."
        case .decoding:
            return "Server response could not be processed."
        }
    }
}
