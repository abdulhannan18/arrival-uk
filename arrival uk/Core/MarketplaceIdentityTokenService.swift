import CryptoKit
import Foundation

struct MarketplaceIdentityTokenPayload: Codable, Hashable {
    let providerID: String
    let userID: String
    let fieldScope: [MarketplaceIdentityField]
    let issuedAtMillis: Int64
    let expiresAtMillis: Int64
    let nonce: String
}

enum MarketplaceIdentityTokenService {
    private static let signingKeyStorageKey = StorageKey.marketplaceIdentitySigningKey.rawValue

    static func issueTemporaryToken(
        providerID: String,
        userID: String,
        requestedFields: [MarketplaceIdentityField],
        ttlSeconds: TimeInterval = 10 * 60
    ) -> String? {
        let now = Date()
        let issuedAtMillis = epochMillis(now)
        let expiresAtMillis = epochMillis(now.addingTimeInterval(max(30, ttlSeconds)))
        let normalizedFields = Array(Set(requestedFields)).sorted { $0.rawValue < $1.rawValue }
        let payload = MarketplaceIdentityTokenPayload(
            providerID: providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            userID: userID.trimmingCharacters(in: .whitespacesAndNewlines),
            fieldScope: normalizedFields,
            issuedAtMillis: issuedAtMillis,
            expiresAtMillis: expiresAtMillis,
            nonce: UUID().uuidString
        )
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            return nil
        }
        let signature = sign(payloadData)

        struct Envelope: Codable {
            let payload: String
            let signature: String
        }

        let envelope = Envelope(
            payload: payloadData.base64EncodedString(),
            signature: signature
        )
        guard let encoded = try? JSONEncoder().encode(envelope) else {
            return nil
        }
        return encoded.base64EncodedString()
    }

    static func validateTemporaryToken(
        _ token: String,
        now: Date = .now
    ) -> MarketplaceIdentityTokenPayload? {
        struct Envelope: Codable {
            let payload: String
            let signature: String
        }

        guard let tokenData = Data(base64Encoded: token),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: tokenData),
              let payloadData = Data(base64Encoded: envelope.payload) else {
            return nil
        }

        guard sign(payloadData) == envelope.signature else { return nil }
        guard let payload = try? JSONDecoder().decode(MarketplaceIdentityTokenPayload.self, from: payloadData) else {
            return nil
        }

        let nowMillis = epochMillis(now)
        guard payload.expiresAtMillis > nowMillis else { return nil }
        guard payload.expiresAtMillis - payload.issuedAtMillis <= Int64(10 * 60 * 1000) else { return nil }
        return payload
    }

    private static func sign(_ payloadData: Data) -> String {
        let key = loadOrCreateSigningKey()
        let digest = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
        return Data(digest).base64EncodedString()
    }

    private static func loadOrCreateSigningKey() -> SymmetricKey {
        if let existing = KeychainManager.loadString(for: signingKeyStorageKey),
           let data = Data(base64Encoded: existing) {
            return SymmetricKey(data: data)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let keyData: Data
        if status == errSecSuccess {
            keyData = Data(bytes)
        } else {
            keyData = Data(SHA256.hash(data: Data(UUID().uuidString.utf8)))
        }

        _ = KeychainManager.saveString(keyData.base64EncodedString(), for: signingKeyStorageKey)
        return SymmetricKey(data: keyData)
    }

    private static func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
