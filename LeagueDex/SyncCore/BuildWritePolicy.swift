/// Resolves an outbox operation against the revision read by a Firestore transaction.
/// Mutation IDs acknowledge a lost commit response without applying the same edit twice.
public enum BuildWritePolicy: Equatable, Sendable {
    case alreadyApplied(revision: Int)
    case write(revision: Int)
    case conflict

    public nonisolated static func resolve(
        expectedRevision: Int,
        serverRevision: Int,
        mutationID: String,
        serverMutationID: String?,
        predecessorMutationID: String?
    ) -> BuildWritePolicy {
        guard expectedRevision >= 0, serverRevision >= 0, !mutationID.isEmpty else {
            return .conflict
        }
        if serverMutationID == mutationID {
            return .alreadyApplied(revision: serverRevision)
        }

        let expectedSuccessor = expectedRevision.addingReportingOverflow(1)
        let nextServerRevision = serverRevision.addingReportingOverflow(1)
        guard !nextServerRevision.overflow else { return .conflict }

        if serverRevision == expectedRevision {
            return .write(revision: nextServerRevision.partialValue)
        }
        // A newer local edit may supersede an operation whose ACK was lost during
        // a crash or account switch. It can follow that exact immediate predecessor,
        // but must not overwrite a subsequent change from another device.
        if !expectedSuccessor.overflow,
           serverRevision == expectedSuccessor.partialValue,
           let predecessorMutationID, !predecessorMutationID.isEmpty,
           serverMutationID == predecessorMutationID {
            return .write(revision: nextServerRevision.partialValue)
        }
        return .conflict
    }
}
