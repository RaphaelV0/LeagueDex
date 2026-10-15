import Foundation
import Testing
@testable import SyncCore

@Test func legacyOutboxWithoutMutationTokensRetainsUserEdits() throws {
    let legacy = """
    {"id":"saved-build","name":"Mon build","championID":"catalog-id","itemIDs":["one","one"],
     "revision":7,"deleted":false,"createdAt":100,"updatedAt":200}
    """
    let decoded = try JSONDecoder().decode(CustomBuild.self, from: Data(legacy.utf8))
    #expect(decoded.name == "Mon build")
    #expect(decoded.itemIDs == ["one", "one"])
    #expect(decoded.revision == 7)
    #expect(!decoded.mutationID.isEmpty)
    #expect(decoded.predecessorMutationID == nil)
    let restored = try JSONDecoder().decode(CustomBuild.self, from: JSONEncoder().encode(decoded))
    #expect(restored == decoded)
}

@Test func pendingDeletionAndLostAcknowledgmentTokensSurviveRelaunch() throws {
    let pending = CustomBuild(name: "Supprimé", championID: "catalog-id", itemIDs: [],
                              revision: 4, deleted: true, mutationID: "new-edit", predecessorMutationID: "submitted-edit")
    let restored = try JSONDecoder().decode([String: CustomBuild].self,
        from: JSONEncoder().encode([pending.id: pending]))
    #expect(restored[pending.id] == pending)
    let decision = BuildWritePolicy.resolve(expectedRevision: pending.revision, serverRevision: 5,
        mutationID: pending.mutationID, serverMutationID: "submitted-edit",
        predecessorMutationID: restored[pending.id]?.predecessorMutationID)
    #expect(decision == .write(revision: 6))
}
