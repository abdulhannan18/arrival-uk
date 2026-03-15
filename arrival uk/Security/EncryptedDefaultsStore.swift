import Foundation
import CryptoKit
import Security

enum EncryptedDefaultsStoreError: Error {
    case invalidKeyMaterial
    case randomGenerationFailed(OSStatus)
    case invalidCipherEnvelope
}

private struct EncryptedDefaultsEnvelope: Codable {
    let nonce: Data
    let ciphertext: Data
    let tag: Data
}

enum EncryptedDefaultsStore {
    static func save(
        _ payload: Data,
        for storageKey: String,
        keychainKey: String,
        defaults: UserDefaults = .standard
    ) throws {
        let key = try symmetricKey(for: keychainKey)
        let sealed = try AES.GCM.seal(payload, using: key)
        let envelope = EncryptedDefaultsEnvelope(
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )

        let encodedEnvelope = try JSONEncoder().encode(envelope)
        defaults.set(encodedEnvelope, forKey: storageKey)
    }

    static func load(
        for storageKey: String,
        keychainKey: String,
        defaults: UserDefaults = .standard
    ) throws -> Data? {
        guard let encodedEnvelope = defaults.data(forKey: storageKey) else {
            return nil
        }

        let envelope = try JSONDecoder().decode(EncryptedDefaultsEnvelope.self, from: encodedEnvelope)
        let nonce = try AES.GCM.Nonce(data: envelope.nonce)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: envelope.ciphertext,
            tag: envelope.tag
        )

        let key = try symmetricKey(for: keychainKey)
        return try AES.GCM.open(sealedBox, using: key)
    }

    static func remove(
        for storageKey: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: storageKey)
    }

    /// Removes the encrypted payload and deletes the underlying key material from Keychain.
    /// Use this when users request local data deletion.
    static func wipe(
        storageKey: String,
        keychainKey: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: storageKey)
        _ = KeychainManager.delete(for: keychainKey)
    }

    private static func symmetricKey(for keychainKey: String) throws -> SymmetricKey {
        if let existing = KeychainManager.load(for: keychainKey) {
            guard existing.count == 32 else {
                throw EncryptedDefaultsStoreError.invalidKeyMaterial
            }
            return SymmetricKey(data: existing)
        }

        let keyData = try randomBytes(count: 32)
        try KeychainManager.saveThrowing(
            data: keyData,
            for: keychainKey,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )

        return SymmetricKey(data: keyData)
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw EncryptedDefaultsStoreError.randomGenerationFailed(status)
        }

        return Data(bytes)
    }
}
