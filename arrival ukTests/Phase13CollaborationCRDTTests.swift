import XCTest
@testable import arrival_uk

final class Phase13CollaborationCRDTTests: XCTestCase {
    func testLWWMergePrefersHigherLamportTimestamp() {
        let baseline = CollaborativeTaskRecord(
            id: "task-bank-account",
            title: "Open Bank Account",
            categoryID: "finance",
            status: .pending,
            isTier1Urgent: true,
            lastEditedBy: "userA",
            timestamp: LamportTimestamp(counter: 4, actorID: "userA"),
            completedAtMillis: nil
        )
        let completion = CollaborativeTaskRecord(
            id: "task-bank-account",
            title: "Open Bank Account",
            categoryID: "finance",
            status: .completed,
            isTier1Urgent: true,
            lastEditedBy: "userB",
            timestamp: LamportTimestamp(counter: 5, actorID: "userB"),
            completedAtMillis: 1_737_000_000_000
        )

        var leftReplica = CollaborativeTaskLWWSet()
        leftReplica.upsert(baseline)
        var rightReplica = CollaborativeTaskLWWSet()
        rightReplica.upsert(completion)

        leftReplica.merge(with: rightReplica)
        let resolved = leftReplica.resolvedEntries

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.status, .completed)
        XCTAssertEqual(resolved.first?.lastEditedBy, "userB")
    }

    func testSplitBrainMergeKeepsSingleTaskVersion() {
        let initial = CollaborativeTaskRecord(
            id: "task-ni-number",
            title: "Apply for National Insurance Number",
            categoryID: "docs",
            status: .pending,
            isTier1Urgent: false,
            lastEditedBy: "seed",
            timestamp: LamportTimestamp(counter: 1, actorID: "seed"),
            completedAtMillis: nil
        )

        var replicaA = CollaborativeTaskLWWSet()
        var replicaB = CollaborativeTaskLWWSet()
        replicaA.upsert(initial)
        replicaB.upsert(initial)

        replicaA.upsert(
            CollaborativeTaskRecord(
                id: initial.id,
                title: initial.title,
                categoryID: initial.categoryID,
                status: .completed,
                isTier1Urgent: false,
                lastEditedBy: "userA",
                timestamp: LamportTimestamp(counter: 8, actorID: "userA"),
                completedAtMillis: 1_737_000_000_500
            )
        )
        replicaB.upsert(
            CollaborativeTaskRecord(
                id: initial.id,
                title: initial.title,
                categoryID: initial.categoryID,
                status: .pending,
                isTier1Urgent: false,
                lastEditedBy: "userB",
                timestamp: LamportTimestamp(counter: 9, actorID: "userB"),
                completedAtMillis: nil
            )
        )

        replicaA.merge(with: replicaB)
        replicaB.merge(with: replicaA)

        XCTAssertEqual(replicaA.resolvedEntries.count, 1)
        XCTAssertEqual(replicaB.resolvedEntries.count, 1)
        XCTAssertEqual(replicaA.resolvedEntries.first?.status, replicaB.resolvedEntries.first?.status)
    }

    func testWalletShareTokenExpiresAndValidatesSignature() {
        let token = WalletShareAuthorizationService.issueToken(
            documentID: UUID(),
            issuedBy: "mentor-user",
            ttlSeconds: 60,
            allowsSensitiveFields: false
        )

        XCTAssertTrue(WalletShareAuthorizationService.validate(token))
        XCTAssertFalse(
            WalletShareAuthorizationService.validate(
                token,
                now: Date(timeIntervalSince1970: TimeInterval(token.expiresAtMillis) / 1000 + 5)
            )
        )
    }
}
