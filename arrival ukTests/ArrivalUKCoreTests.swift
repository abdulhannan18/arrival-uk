import XCTest
@testable import arrival_uk

@MainActor
final class ArrivalUKCoreTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        setenv("ARRIVAL_KEYCHAIN_BACKEND", "memory", 1)
    }

    override class func tearDown() {
        unsetenv("ARRIVAL_KEYCHAIN_BACKEND")
        super.tearDown()
    }

    private func waitUntil(
        timeoutSeconds: TimeInterval,
        pollNanoseconds: UInt64 = 50_000_000,
        condition: @escaping @Sendable () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }

    func testExternalURLPolicyAllowsTrustedHTTPS() {
        let url = URL(string: "https://www.gov.uk/student-visa")!
        XCTAssertTrue(ExternalURLPolicy.isAllowed(url))
    }

    func testExternalURLPolicyBlocksUntrustedHTTP() {
        let url = URL(string: "http://example.com/path")!
        XCTAssertFalse(ExternalURLPolicy.isAllowed(url))
    }

    func testExternalURLPolicyBlocksIPAddressHosts() {
        let ipv4 = URL(string: "https://192.168.0.1/admin")!
        XCTAssertFalse(ExternalURLPolicy.isAllowed(ipv4))

        let ipv6 = URL(string: "https://[::1]/")!
        XCTAssertFalse(ExternalURLPolicy.isAllowed(ipv6))
    }

    func testKeychainUnexpiredStringThrowsExpiredAndCleansValue() throws {
        let key = "test.expiring.\(UUID().uuidString)"
        defer { _ = KeychainManager.delete(for: key) }

        try KeychainManager.saveExpiringStringThrowing(
            "token-value",
            for: key,
            expiresAt: Date().addingTimeInterval(-30)
        )

        XCTAssertThrowsError(try KeychainManager.loadUnexpiredStringThrowing(for: key)) { error in
            guard case KeychainManager.KeychainError.expired = error else {
                XCTFail("Expected KeychainError.expired, got \(error)")
                return
            }
        }
        XCTAssertNil(KeychainManager.loadString(for: key))
    }

    func testEncryptedDefaultsRoundTrip() throws {
        let suiteName = "arrivaluk.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }

        let storageKey = "encrypted.defaults.key"
        let keychainKey = "encrypted.defaults.secret.\(UUID().uuidString)"
        let payload = Data("hello-world".utf8)

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            _ = KeychainManager.delete(for: keychainKey)
        }

        try EncryptedDefaultsStore.save(
            payload,
            for: storageKey,
            keychainKey: keychainKey,
            defaults: defaults
        )

        let loaded = try EncryptedDefaultsStore.load(
            for: storageKey,
            keychainKey: keychainKey,
            defaults: defaults
        )

        XCTAssertEqual(loaded, payload)
    }

    func testEncryptedDefaultsWipeRemovesPayloadAndKeyMaterial() throws {
        let suiteName = "arrivaluk.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }

        let storageKey = "encrypted.defaults.wipe.payload"
        let keychainKey = "encrypted.defaults.wipe.secret.\(UUID().uuidString)"
        let payload = Data("wipe-me".utf8)

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            _ = KeychainManager.delete(for: keychainKey)
        }

        try EncryptedDefaultsStore.save(
            payload,
            for: storageKey,
            keychainKey: keychainKey,
            defaults: defaults
        )

        XCTAssertNotNil(defaults.data(forKey: storageKey))
        XCTAssertNotNil(KeychainManager.load(for: keychainKey))

        EncryptedDefaultsStore.wipe(
            storageKey: storageKey,
            keychainKey: keychainKey,
            defaults: defaults
        )

        XCTAssertNil(defaults.data(forKey: storageKey))
        XCTAssertNil(KeychainManager.load(for: keychainKey))
        XCTAssertNil(try EncryptedDefaultsStore.load(for: storageKey, keychainKey: keychainKey, defaults: defaults))
    }

    func testAuthStateValidatorRejectsInvalidGoogleEmailFallback() {
        let snapshot = StudentProfileSnapshot(
            authProvider: .google,
            appleUserID: nil,
            googleUserID: nil,
            fullName: "Test User",
            email: "a@",
            selectedUniversity: "University of Oxford",
            courseName: "CS",
            city: "Oxford",
            studyLevel: .undergraduate,
            arrivalDate: .now,
            hasCompletedSetup: true
        )

        let normalized = AuthStateValidator.normalize(snapshot)
        XCTAssertEqual(normalized.authProvider, .none)
        XCTAssertEqual(normalized.email, "")
    }

    func testAuthStateValidatorAcceptsValidGoogleEmailFallback() {
        let snapshot = StudentProfileSnapshot(
            authProvider: .google,
            appleUserID: nil,
            googleUserID: nil,
            fullName: "Test User",
            email: "student@example.com",
            selectedUniversity: "University of Oxford",
            courseName: "CS",
            city: "Oxford",
            studyLevel: .undergraduate,
            arrivalDate: .now,
            hasCompletedSetup: true
        )

        let normalized = AuthStateValidator.normalize(snapshot)
        XCTAssertEqual(normalized.authProvider, .google)
        XCTAssertEqual(normalized.email, "student@example.com")
    }

    func testProgressSnapshotComponentsIncludesCompletedAndCustomTasks() {
        let completed = ChecklistTask(
            id: "task.completed",
            title: "Completed",
            isComplete: true,
            isCustom: false
        )
        let custom = ChecklistTask(
            id: "task.custom",
            title: "Custom",
            isComplete: false,
            isCustom: true
        )
        let regular = ChecklistTask(
            id: "task.regular",
            title: "Regular",
            isComplete: false,
            isCustom: false
        )

        let categories: [ChecklistCategory] = [
            ChecklistCategory(
                id: "cat.one",
                title: "One",
                icon: "house.fill",
                tasks: [completed, regular]
            ),
            ChecklistCategory(
                id: "cat.two",
                title: "Two",
                icon: "book.fill",
                tasks: [custom]
            )
        ]

        let snapshot = ContentStore.progressSnapshotComponents(from: categories)

        XCTAssertEqual(snapshot.completedTaskIDs, ["task.completed"])
        XCTAssertEqual(snapshot.customTasksByCategory.keys.sorted(), ["cat.two"])
        XCTAssertEqual(snapshot.customTasksByCategory["cat.two"]?.map(\.id), ["task.custom"])
    }

    func testPersistProgressWritesEncryptedSnapshotAndRemovesLegacyProgress() async {
        let store = ContentStore()
        let encryptedProgressKey = StorageKey.contentProgressV2Encrypted.rawValue
        let legacyProgressKey = StorageKey.contentProgressV1Legacy.rawValue
        let progressEncryptionKey = StorageKey.contentProgressEncryptionKey.rawValue

        defer {
            UserDefaults.standard.removeObject(forKey: encryptedProgressKey)
            UserDefaults.standard.removeObject(forKey: legacyProgressKey)
            _ = KeychainManager.delete(for: progressEncryptionKey)
        }

        let sampleCategories: [ChecklistCategory] = [
            ChecklistCategory(
                id: "cat.sample",
                title: "Sample",
                icon: "house.fill",
                tasks: [
                    ChecklistTask(id: "task.done", title: "Done", isComplete: true),
                    ChecklistTask(id: "task.custom", title: "Custom", isCustom: true)
                ]
            )
        ]

        await MainActor.run {
            store.categories = sampleCategories
            UserDefaults.standard.set(Data("legacy".utf8), forKey: legacyProgressKey)
            store.persistProgress()
        }

        let persisted = await waitUntil(timeoutSeconds: 5.0) {
            UserDefaults.standard.data(forKey: encryptedProgressKey) != nil
            && UserDefaults.standard.object(forKey: legacyProgressKey) == nil
        }

        XCTAssertTrue(persisted, "Expected encrypted progress data to be stored and legacy key removed.")
    }

    func testKeychainRejectsUnreasonableFutureExpiry() throws {
        let key = "test.expiring.future.\(UUID().uuidString)"
        defer { _ = KeychainManager.delete(for: key) }

        let farFuture = Date().addingTimeInterval((366 * 24 * 60 * 60))
        try KeychainManager.saveExpiringStringThrowing(
            "token-value",
            for: key,
            expiresAt: farFuture
        )

        XCTAssertThrowsError(try KeychainManager.loadUnexpiredStringThrowing(for: key)) { error in
            guard case KeychainManager.KeychainError.invalidData = error else {
                XCTFail("Expected KeychainError.invalidData, got \(error)")
                return
            }
        }
        XCTAssertNil(KeychainManager.loadString(for: key))
    }
}
