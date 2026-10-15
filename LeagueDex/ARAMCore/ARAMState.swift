import Foundation

/// Presentation state independent of SwiftUI and UIKit. One physical event can
/// select at most once, even when it reaches the app during a modal transition.
struct ARAMState: Sendable {
    enum Phase: Equatable, Sendable {
        case idle
        case opening
        case presented
        case closing
    }

    enum ShakeResult: Equatable, Sendable {
        case ignored
        case opened
        case replaced
        case deferred

        var isAccepted: Bool { self != .ignored }
    }

    struct Session: Identifiable, Equatable, Sendable {
        let id: UUID
        var championID: String
        var revision: Int
    }

    private(set) var phase: Phase = .idle
    private(set) var session: Session?
    private(set) var pendingChampionID: String?
    private(set) var isGalleryPresented = false

    private let minimumShakeInterval: TimeInterval
    private var lastAcceptedTimestamp: TimeInterval?
    private var recentEventIDs: [UUID] = []
    private var pendingRevision = 0
    private var gallerySessionID: UUID?

    init(minimumShakeInterval: TimeInterval = 0.3) {
        self.minimumShakeInterval = max(0, minimumShakeInterval)
    }

    /// `timestamp` must come from a monotonic clock (systemUptime), not Date.
    /// The caller supplies filtered catalog IDs on the catalog, or all IDs when
    /// viewing a detail/session. Selection remains injectable for native tests.
    @discardableResult
    mutating func receiveShake(
        eventID: UUID,
        timestamp: TimeInterval,
        isActive: Bool,
        sceneIsActive: Bool,
        candidateIDs: [String],
        currentChampionID: String? = nil,
        selectIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> ShakeResult {
        guard !recentEventIDs.contains(eventID) else { return .ignored }
        recentEventIDs.append(eventID)
        if recentEventIDs.count > 64 {
            recentEventIDs.removeFirst(recentEventIDs.count - 64)
        }

        guard isActive, sceneIsActive, timestamp.isFinite else { return .ignored }
        if let lastAcceptedTimestamp,
           timestamp - lastAcceptedTimestamp < minimumShakeInterval {
            return .ignored
        }

        let currentID = pendingChampionID ?? session?.championID ?? currentChampionID
        var seen = Set<String>()
        let uniqueIDs = candidateIDs.filter { !$0.isEmpty && seen.insert($0).inserted }
        let alternatives = uniqueIDs.filter { $0 != currentID }
        let candidates = alternatives.isEmpty ? uniqueIDs : alternatives
        guard !candidates.isEmpty else { return .ignored }
        let index = selectIndex(candidates.count)
        guard candidates.indices.contains(index) else { return .ignored }

        let championID = candidates[index]
        lastAcceptedTimestamp = timestamp
        let revision = max(session?.revision ?? 0, pendingRevision) + 1

        if phase == .closing || isGalleryPresented {
            pendingChampionID = championID
            pendingRevision = revision
            return .deferred
        }

        if var activeSession = session {
            activeSession.championID = championID
            activeSession.revision = revision
            session = activeSession
            return .replaced
        }

        session = Session(id: UUID(), championID: championID, revision: revision)
        phase = .opening
        return .opened
    }

    mutating func presentationDidAppear(sessionID: UUID) {
        guard session?.id == sessionID, phase == .opening else { return }
        phase = .presented
    }

    /// Closing is synchronous: callers can remove the cover immediately. A
    /// later shake is retained until SwiftUI reports the actual dismissal.
    mutating func close(sessionID: UUID) {
        guard session?.id == sessionID, phase != .closing else { return }
        phase = .closing
        pendingChampionID = nil
        pendingRevision = 0
        isGalleryPresented = false
        gallerySessionID = nil
    }

    mutating func presentationDidDismiss(
        sessionID: UUID,
        isActive: Bool,
        sceneIsActive: Bool
    ) {
        guard session?.id == sessionID, phase == .closing else { return }
        session = nil
        phase = .idle
        applyPendingSelection(isActive: isActive, sceneIsActive: sceneIsActive)
    }

    /// A nil session ID identifies a skin gallery opened from a normal detail.
    /// Session IDs make late callbacks from replaced views harmless.
    mutating func setGalleryPresented(
        _ presented: Bool,
        sessionID: UUID? = nil,
        isActive: Bool = true,
        sceneIsActive: Bool = true
    ) {
        if presented {
            guard phase != .closing, session?.id == sessionID else { return }
            isGalleryPresented = true
            gallerySessionID = sessionID
        } else {
            guard isGalleryPresented, gallerySessionID == sessionID else { return }
            isGalleryPresented = false
            gallerySessionID = nil
            applyPendingSelection(isActive: isActive, sceneIsActive: sceneIsActive)
        }
    }

    /// Prevents a deferred event from opening ARAM after switching tabs or
    /// returning from the background. An already displayed session may remain.
    mutating func discardPendingSelection() {
        pendingChampionID = nil
        pendingRevision = 0
    }

    private mutating func applyPendingSelection(isActive: Bool, sceneIsActive: Bool) {
        guard isActive, sceneIsActive else {
            discardPendingSelection()
            return
        }
        guard let championID = pendingChampionID, phase != .closing else { return }
        let revision = pendingRevision
        discardPendingSelection()

        if var activeSession = session {
            activeSession.championID = championID
            activeSession.revision = revision
            session = activeSession
        } else {
            session = Session(id: UUID(), championID: championID, revision: revision)
            phase = .opening
        }
    }
}
