import Foundation
import Security

enum KeychainManager {
    private struct ExpiringSecret: Codable {
        let value: String
        let expiresAt: Date
    }

    private static let testingBackendEnvKey = "ARRIVAL_KEYCHAIN_BACKEND"
    private static let inMemoryBackendValue = "memory"
    private static var inMemoryStore: [String: Data] = [:]
    private static let inMemoryStoreLock = NSLock()

    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case expired
        case invalidData
        case unhandledError(status: OSStatus)
    }

    private static var serviceName: String {
        Bundle.main.bundleIdentifier ?? "com.arrivaluk.arrival-uk"
    }

    private static var usesInMemoryBackend: Bool {
        ProcessInfo.processInfo.environment[testingBackendEnvKey]?.lowercased() == inMemoryBackendValue
    }

    private static func baseQuery(for key: String, includeService: Bool = true) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        if includeService {
            query[kSecAttrService as String] = serviceName
        }

        return query
    }

    @discardableResult
    static func save(data: Data, for key: String) -> Bool {
        (try? saveThrowing(data: data, for: key)) != nil
    }

    static func saveThrowing(
        data: Data,
        for key: String,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) throws {
        if usesInMemoryBackend {
            inMemoryStoreLock.lock()
            inMemoryStore[key] = data
            inMemoryStoreLock.unlock()
            return
        }

        var insertQuery = baseQuery(for: key)
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = accessibility

        SecItemDelete(baseQuery(for: key) as CFDictionary)
        SecItemDelete(baseQuery(for: key, includeService: false) as CFDictionary)

        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        if insertStatus == errSecSuccess {
            return
        }

        if insertStatus == errSecDuplicateItem {
            let updates: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(baseQuery(for: key) as CFDictionary, updates as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
            return
        }

        throw KeychainError.unhandledError(status: insertStatus)
    }

    static func load(for key: String) -> Data? {
        try? loadThrowing(for: key)
    }

    static func loadThrowing(for key: String) throws -> Data {
        if usesInMemoryBackend {
            inMemoryStoreLock.lock()
            let data = inMemoryStore[key]
            inMemoryStoreLock.unlock()

            guard let data else {
                throw KeychainError.itemNotFound
            }
            return data
        }

        var namespacedQuery = baseQuery(for: key)
        namespacedQuery[kSecReturnData as String] = true
        namespacedQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        do {
            return try loadData(with: namespacedQuery)
        } catch KeychainError.itemNotFound {
            var legacyQuery = baseQuery(for: key, includeService: false)
            legacyQuery[kSecReturnData as String] = true
            legacyQuery[kSecMatchLimit as String] = kSecMatchLimitOne

            let legacyData = try loadData(with: legacyQuery)
            try? saveThrowing(data: legacyData, for: key)
            return legacyData
        }
    }

    private static func loadData(with query: [String: Any]) throws -> Data {
        var mutableQuery = query
        mutableQuery[kSecReturnData as String] = true
        mutableQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(mutableQuery as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        return data
    }

    @discardableResult
    static func delete(for key: String) -> Bool {
        (try? deleteThrowing(for: key)) != nil
    }

    static func deleteThrowing(for key: String) throws {
        if usesInMemoryBackend {
            inMemoryStoreLock.lock()
            inMemoryStore.removeValue(forKey: key)
            inMemoryStoreLock.unlock()
            return
        }

        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        let legacyStatus = SecItemDelete(baseQuery(for: key, includeService: false) as CFDictionary)

        let allowedStatuses: Set<OSStatus> = [errSecSuccess, errSecItemNotFound]
        guard allowedStatuses.contains(status) else {
            throw KeychainError.unhandledError(status: status)
        }
        guard allowedStatuses.contains(legacyStatus) else {
            throw KeychainError.unhandledError(status: legacyStatus)
        }
    }

    @discardableResult
    static func saveString(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return (try? saveThrowing(data: data, for: key)) != nil
    }

    static func loadString(for key: String) -> String? {
        guard let data = try? loadThrowing(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveStringThrowing(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try saveThrowing(data: data, for: key)
    }

    static func loadStringThrowing(for key: String) throws -> String {
        let data = try loadThrowing(for: key)
        guard let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    @discardableResult
    static func saveExpiringString(
        _ value: String,
        for key: String,
        expiresAt: Date,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) -> Bool {
        (try? saveExpiringStringThrowing(
            value,
            for: key,
            expiresAt: expiresAt,
            accessibility: accessibility
        )) != nil
    }

    static func saveExpiringStringThrowing(
        _ value: String,
        for key: String,
        expiresAt: Date,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) throws {
        let payload = ExpiringSecret(value: value, expiresAt: expiresAt)
        let encoded = try JSONEncoder().encode(payload)
        try saveThrowing(data: encoded, for: key, accessibility: accessibility)
    }

    @discardableResult
    static func saveExpiringString(
        _ value: String,
        for key: String,
        ttl: TimeInterval,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) -> Bool {
        let expiresAt = Date().addingTimeInterval(max(0, ttl))
        return saveExpiringString(
            value,
            for: key,
            expiresAt: expiresAt,
            accessibility: accessibility
        )
    }

    static func loadUnexpiredString(for key: String, now: Date = Date()) -> String? {
        try? loadUnexpiredStringThrowing(for: key, now: now)
    }

    static func loadUnexpiredStringThrowing(
        for key: String,
        now: Date = Date(),
        allowedClockSkewSeconds: TimeInterval = 30
    ) throws -> String? {
        let data = try loadThrowing(for: key)
        let payload = try JSONDecoder().decode(ExpiringSecret.self, from: data)
        let skewAdjustedNow = now.addingTimeInterval(-max(0, allowedClockSkewSeconds))
        let maxReasonableExpiry = now.addingTimeInterval(365 * 24 * 60 * 60)

        guard payload.expiresAt <= maxReasonableExpiry else {
            try? deleteThrowing(for: key)
            throw KeychainError.invalidData
        }

        guard payload.expiresAt > skewAdjustedNow else {
            try? deleteThrowing(for: key)
            throw KeychainError.expired
        }

        return payload.value
    }
}
