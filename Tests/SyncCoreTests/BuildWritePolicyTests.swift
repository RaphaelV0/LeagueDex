import Testing
@testable import SyncCore

@Suite("Build outbox revision and crash recovery")
struct BuildWritePolicyTests {
    @Test("A new build starts at revision one")
    func createBuild() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 0, serverRevision: 0,
            mutationID: "create-device-A", serverMutationID: nil, predecessorMutationID: nil
        ) == .write(revision: 1))
    }

    @Test("An edit of the observed server revision advances once")
    func editKnownRevision() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 7,
            mutationID: "edit-device-A", serverMutationID: "previous-edit", predecessorMutationID: nil
        ) == .write(revision: 8))
    }

    @Test("A commit whose ACK was lost is acknowledged without a duplicate write")
    func recoverLostAcknowledgement() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 8,
            mutationID: "committed-before-crash", serverMutationID: "committed-before-crash", predecessorMutationID: nil
        ) == .alreadyApplied(revision: 8))
    }

    @Test("Creating offline then losing the first ACK does not create another revision")
    func recoverInitialCommit() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 0, serverRevision: 1,
            mutationID: "offline-create", serverMutationID: "offline-create", predecessorMutationID: nil
        ) == .alreadyApplied(revision: 1))
    }

    @Test("A newer local edit can follow its in-flight predecessor after restart")
    func recoverSupersededInFlightEdit() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 8,
            mutationID: "newer-local-edit", serverMutationID: "earlier-in-flight-edit",
            predecessorMutationID: "earlier-in-flight-edit"
        ) == .write(revision: 9))
    }

    @Test("A predecessor token does not block an edit before that predecessor committed")
    func predecessorHasNotCommitted() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 7,
            mutationID: "newer-local-edit", serverMutationID: "base-edit",
            predecessorMutationID: "earlier-in-flight-edit"
        ) == .write(revision: 8))
    }

    @Test("Another device's intervening edit remains a conflict")
    func doNotOverwriteAnotherDevice() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 8,
            mutationID: "edit-device-A", serverMutationID: "edit-device-B",
            predecessorMutationID: "earlier-device-A-edit"
        ) == .conflict)
    }

    @Test("Matching an old predecessor cannot skip multiple intervening revisions")
    func predecessorMustBeImmediate() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 9,
            mutationID: "edit-device-A", serverMutationID: "earlier-device-A-edit",
            predecessorMutationID: "earlier-device-A-edit"
        ) == .conflict)
    }

    @Test("A missing or older server revision never silently recreates an existing build")
    func serverRevisionMovedBackwards() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 0,
            mutationID: "edit-device-A", serverMutationID: nil, predecessorMutationID: nil
        ) == .conflict)
    }

    @Test("Missing mutation identity cannot acknowledge an unknown operation")
    func emptyMutationID() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: 7, serverRevision: 8,
            mutationID: "", serverMutationID: "", predecessorMutationID: nil
        ) == .conflict)
    }

    @Test("Malformed revisions cannot wrap or crash the transaction worker")
    func revisionBounds() {
        #expect(BuildWritePolicy.resolve(
            expectedRevision: -1, serverRevision: 0,
            mutationID: "edit", serverMutationID: nil, predecessorMutationID: nil
        ) == .conflict)
        #expect(BuildWritePolicy.resolve(
            expectedRevision: Int.max, serverRevision: Int.max,
            mutationID: "edit", serverMutationID: "previous", predecessorMutationID: nil
        ) == .conflict)
        #expect(BuildWritePolicy.resolve(
            expectedRevision: Int.max - 1, serverRevision: Int.max,
            mutationID: "edit", serverMutationID: "predecessor", predecessorMutationID: "predecessor"
        ) == .conflict)
    }

    @Test("The decision can be computed on a detached transaction worker")
    func nonisolatedWorker() async {
        let result = await Task.detached {
            BuildWritePolicy.resolve(
                expectedRevision: 3, serverRevision: 4,
                mutationID: "new-edit", serverMutationID: "submitted-edit", predecessorMutationID: "submitted-edit"
            )
        }.value
        #expect(result == .write(revision: 5))
    }
}
