import CryptoKit
import Foundation

struct WalletShareGrantToken: Codable, Hashable {
    let documentID: String
    let issuedBy: String
    let issuedAtMillis: Int64
    let expiresAtMillis: Int64
    let nonce: String
    let allowsSensitiveFields: Bool
    let signature: String
}

enum WalletShareAuthorizationService {
    private static let signingKeyStorageKey = StorageKey.walletShareSigningKey.rawValue
    static var testingSigningKeyProvider: (() -> SymmetricKey?)?

    static func issueToken(
        documentID: UUID,
        issuedBy: String,
        ttlSeconds: TimeInterval = 300,
        allowsSensitiveFields: Bool
    ) -> WalletShareGrantToken? {
        let now = Date()
        let expiresAt = now.addingTimeInterval(max(30, ttlSeconds))
        let issuedAtMillis = epochMillis(now)
        let expiresAtMillis = epochMillis(expiresAt)
        let nonce = UUID().uuidString
        let canonical = canonicalPayload(
            documentID: documentID.uuidString,
            issuedBy: issuedBy,
            issuedAtMillis: issuedAtMillis,
            expiresAtMillis: expiresAtMillis,
            nonce: nonce,
            allowsSensitiveFields: allowsSensitiveFields
        )
        guard let signature = sign(canonical) else {
            return nil
        }

        return WalletShareGrantToken(
            documentID: documentID.uuidString,
            issuedBy: issuedBy,
            issuedAtMillis: issuedAtMillis,
            expiresAtMillis: expiresAtMillis,
            nonce: nonce,
            allowsSensitiveFields: allowsSensitiveFields,
            signature: signature
        )
    }

    static func validate(
        _ token: WalletShareGrantToken,
        now: Date = .now
    ) -> Bool {
        let nowMillis = epochMillis(now)
        guard token.expiresAtMillis > nowMillis else { return false }
        guard token.expiresAtMillis - token.issuedAtMillis <= Int64(60 * 60 * 1000) else {
            return false
        }

        let canonical = canonicalPayload(
            documentID: token.documentID,
            issuedBy: token.issuedBy,
            issuedAtMillis: token.issuedAtMillis,
            expiresAtMillis: token.expiresAtMillis,
            nonce: token.nonce,
            allowsSensitiveFields: token.allowsSensitiveFields
        )
        guard let expectedSignature = sign(canonical) else {
            return false
        }
        return expectedSignature == token.signature
    }

    static func encodeToken(_ token: WalletShareGrantToken) -> String? {
        guard let data = try? JSONEncoder().encode(token) else { return nil }
        return data.base64EncodedString()
    }

    static func decodeToken(_ encoded: String) -> WalletShareGrantToken? {
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(WalletShareGrantToken.self, from: data)
    }

    private static func sign(_ canonicalPayload: String) -> String? {
        guard let key = loadOrCreateSigningKey() else {
            return nil
        }
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data(canonicalPayload.utf8),
            using: key
        )
        return Data(digest).base64EncodedString()
    }

    private static func loadOrCreateSigningKey() -> SymmetricKey? {
        if let testingSigningKeyProvider {
            return testingSigningKeyProvider()
        }

        if let existing = KeychainManager.loadString(for: signingKeyStorageKey),
           let data = Data(base64Encoded: existing) {
            return SymmetricKey(data: data)
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }

        let data = Data(bytes)
        guard KeychainManager.saveString(data.base64EncodedString(), for: signingKeyStorageKey) else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    private static func canonicalPayload(
        documentID: String,
        issuedBy: String,
        issuedAtMillis: Int64,
        expiresAtMillis: Int64,
        nonce: String,
        allowsSensitiveFields: Bool
    ) -> String {
        [
            documentID,
            issuedBy,
            String(issuedAtMillis),
            String(expiresAtMillis),
            nonce,
            allowsSensitiveFields ? "1" : "0"
        ].joined(separator: "|")
    }

    private static func epochMillis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}
