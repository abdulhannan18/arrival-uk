import XCTest
@testable import arrival_uk

final class CoreSafetyRegressionTests: XCTestCase {
    func testAuthStateValidatorAcceptsAndRejectsExpectedEmails() {
        XCTAssertTrue(AuthStateValidator.isValidEmail("student@example.ac.uk"))
        XCTAssertTrue(AuthStateValidator.isValidEmail("Student.Name+tag@Example.COM"))
        XCTAssertFalse(AuthStateValidator.isValidEmail(""))
        XCTAssertFalse(AuthStateValidator.isValidEmail("not-an-email"))
        XCTAssertFalse(AuthStateValidator.isValidEmail("user@localhost"))
    }

    func testAuthStateValidatorNormalizeDropsInvalidGoogleIdentity() {
        let snapshot = StudentProfileSnapshot(
            authProvider: .google,
            appleUserID: nil,
            googleUserID: nil,
            fullName: "Test Student",
            email: "not-an-email",
            selectedUniversity: "Example University",
            courseName: "Computer Science",
            city: "London",
            studyLevel: .undergraduate,
            arrivalDate: Date(),
            hasCompletedSetup: true
        )

        let normalized = AuthStateValidator.normalize(snapshot)

        XCTAssertEqual(normalized.authProvider, .none)
        XCTAssertNil(normalized.googleUserID)
        XCTAssertEqual(normalized.email, "")
    }

    func testCategoryColorSystemProducesStableFallbackForUnknownCategoryID() {
        let first = CategoryColorSystem.color(forID: "unknown_category_xyz", index: 4)
        let second = CategoryColorSystem.color(forID: "unknown_category_xyz", index: 4)

        XCTAssertEqual(first.family, second.family)
        XCTAssertEqual(first.tier, second.tier)
        XCTAssertEqual(first.toneIndex, second.toneIndex)
        XCTAssertEqual(first.hex, second.hex)
        XCTAssertTrue(first.tier.validToneRange.contains(first.toneIndex))
    }

    func testArrivalColorClampsOutOfRangeToneIndex() {
        let low = ArrivalColor.hex(family: .financialMidnight, toneIndex: -10)
        let high = ArrivalColor.hex(family: .financialMidnight, toneIndex: 999)

        XCTAssertEqual(low, ArrivalColor.financialMidnight.first)
        XCTAssertEqual(high, ArrivalColor.financialMidnight.last)
    }
}
