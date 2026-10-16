import Foundation

/// A shake picks one champion. SwiftUI owns the full-screen presentation;
/// this type deliberately does not model modal opening/closing transitions.
struct ARAMState: Sendable {
    enum ShakeResult: Equatable, Sendable {
        case ignored
        case opened
        case replaced

        var isAccepted: Bool { self != .ignored }
    }

    private(set) var currentChampionID: String?
    private(set) var revision = 0

    private let minimumShakeInterval: TimeInterval
    private var lastAcceptedTimestamp: TimeInterval?
    private var lastEventID: UUID?

    init(minimumShakeInterval: TimeInterval = 0.45) {
        self.minimumShakeInterval = max(0, minimumShakeInterval)
    }

    /// Accepts one completed UIKit shake and changes the displayed champion.
    /// A different champion is always preferred when the catalog has alternatives.
    @discardableResult
    mutating func receiveShake(
        eventID: UUID,
        timestamp: TimeInterval,
        candidateIDs: [String],
        selectIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> ShakeResult {
        guard timestamp.isFinite else {
            #if DEBUG
            print("[LeagueDex ARAM] Shake ignoré : horodatage non fini")
            #endif
            return .ignored
        }
        guard lastEventID != eventID else {
            #if DEBUG
            print("[LeagueDex ARAM] Shake ignoré : événement déjà traité")
            #endif
            return .ignored
        }
        if let lastAcceptedTimestamp {
            let elapsed = timestamp - lastAcceptedTimestamp
            // A clock discontinuity must not lock ARAM indefinitely. The
            // normal case still suppresses duplicate UIKit callbacks.
            if elapsed >= 0 && elapsed < minimumShakeInterval {
                #if DEBUG
                print("[LeagueDex ARAM] Shake ignoré : délai \(elapsed)s < \(minimumShakeInterval)s")
                #endif
                return .ignored
            }
        }

        var seen = Set<String>()
        let uniqueIDs = candidateIDs.filter { !$0.isEmpty && seen.insert($0).inserted }
        let others = uniqueIDs.filter { $0 != currentChampionID }
        let candidates = others.isEmpty ? uniqueIDs : others
        guard !candidates.isEmpty else { return .ignored }
        let index = selectIndex(candidates.count)
        guard candidates.indices.contains(index) else { return .ignored }

        let alreadyOpen = currentChampionID != nil
        currentChampionID = candidates[index]
        revision += 1
        lastAcceptedTimestamp = timestamp
        lastEventID = eventID
        return alreadyOpen ? .replaced : .opened
    }

    /// Closing ARAM forgets its previous champion, without modifying any
    /// normal NavigationStack path or affecting the next shake.
    mutating func reset() {
        currentChampionID = nil
        revision = 0
    }
}
