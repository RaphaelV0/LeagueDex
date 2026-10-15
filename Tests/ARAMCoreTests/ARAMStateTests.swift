import Foundation
import Testing
@testable import ARAMCore

@Suite("ARAM event and presentation state")
struct ARAMStateTests {
    private let champions = ["Ahri", "Aatrox", "Ashe"]

    @discardableResult
    private func shake(
        _ state: inout ARAMState,
        at time: TimeInterval,
        id: UUID = UUID(),
        active: Bool = true,
        foreground: Bool = true,
        candidates: [String]? = nil,
        currentID: String? = nil
    ) -> ARAMState.ShakeResult {
        state.receiveShake(
            eventID: id,
            timestamp: time,
            isActive: active,
            sceneIsActive: foreground,
            candidateIDs: candidates ?? champions,
            currentChampionID: currentID,
            selectIndex: { _ in 0 }
        )
    }

    @Test("20 distinct gestures replace one stable session")
    func twentyGestures() throws {
        var state = ARAMState()
        #expect(shake(&state, at: 0) == .opened)
        let identity = try #require(state.session?.id)
        state.presentationDidAppear(sessionID: identity)

        for index in 1..<20 {
            let previous = state.session?.championID
            #expect(shake(&state, at: Double(index) * 0.35) == .replaced)
            #expect(state.session?.id == identity)
            #expect(state.session?.championID != previous)
            #expect(state.session?.revision == index + 1)
            #expect(state.phase == .presented)
        }
        #expect(state.pendingChampionID == nil)
    }

    @Test("The same physical event draws only once")
    func duplicateEvent() {
        var state = ARAMState()
        let eventID = UUID()
        #expect(shake(&state, at: 0, id: eventID) == .opened)
        let selection = state.session
        #expect(shake(&state, at: 1, id: eventID) == .ignored)
        #expect(state.session == selection)
    }

    @Test("Repeated notifications are suppressed without swallowing spaced gestures")
    func shortDebounce() {
        var state = ARAMState()
        shake(&state, at: 0)
        let repeatedID = UUID()
        #expect(shake(&state, at: 0.1, id: repeatedID) == .ignored)
        #expect(shake(&state, at: 0.35) == .replaced)
        #expect(shake(&state, at: 1, id: repeatedID) == .ignored)
        #expect(state.session?.revision == 2)
    }

    @Test("A shake during opening changes the same presentation")
    func opening() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let identity = try #require(state.session?.id)
        #expect(shake(&state, at: 0.35) == .replaced)
        #expect(state.session?.id == identity)
        #expect(state.phase == .opening)
        state.presentationDidAppear(sessionID: identity)
        #expect(state.phase == .presented)
    }

    @Test("Closing is immediate, and gestures during dismissal retain the latest choice")
    func closing() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let oldID = try #require(state.session?.id)
        state.presentationDidAppear(sessionID: oldID)
        state.close(sessionID: oldID)
        #expect(state.phase == .closing)
        #expect(shake(&state, at: 0.35) == .deferred)
        #expect(shake(&state, at: 0.7) == .deferred)
        let latest = state.pendingChampionID
        #expect(state.session?.id == oldID)
        state.presentationDidDismiss(sessionID: oldID, isActive: true, sceneIsActive: true)
        #expect(state.phase == .opening)
        #expect(state.session?.id != oldID)
        #expect(state.session?.championID == latest)
        #expect(state.session?.revision == 3)

        // A late dismissal from the previous cover cannot dismiss its successor.
        let reopened = state.session
        state.presentationDidDismiss(sessionID: oldID, isActive: true, sceneIsActive: true)
        state.close(sessionID: oldID)
        state.presentationDidAppear(sessionID: oldID)
        #expect(state.session == reopened)
        #expect(state.phase == .opening)
    }

    @Test("Closing without another gesture returns to idle")
    func closeWithoutShake() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let identity = try #require(state.session?.id)
        state.close(sessionID: identity)
        state.presentationDidDismiss(sessionID: identity, isActive: true, sceneIsActive: true)
        #expect(state.session == nil)
        #expect(state.phase == .idle)
    }

    @Test("A gallery retains its displayed champion and applies the latest draw on dismissal")
    func galleryDefersDraws() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let initial = try #require(state.session)
        state.presentationDidAppear(sessionID: initial.id)
        state.setGalleryPresented(true, sessionID: initial.id)
        #expect(shake(&state, at: 0.35) == .deferred)
        #expect(shake(&state, at: 0.7) == .deferred)
        let latest = state.pendingChampionID
        #expect(state.session?.championID == initial.championID)
        #expect(state.session?.revision == 1)
        state.setGalleryPresented(false, sessionID: initial.id)
        #expect(state.session?.championID == latest)
        #expect(state.session?.id == initial.id)
        #expect(state.session?.revision == 3)
        #expect(state.pendingChampionID == nil)
    }

    @Test("A gallery in a manual detail cannot open ARAM underneath another modal")
    func manualGallery() {
        var state = ARAMState()
        state.setGalleryPresented(true)
        #expect(shake(&state, at: 0, currentID: "Ahri") == .deferred)
        #expect(state.session == nil)
        #expect(state.phase == .idle)
        state.setGalleryPresented(false)
        #expect(state.phase == .opening)
        #expect(state.session?.championID == "Aatrox")
    }

    @Test("Inactive tabs and background scenes never select a champion")
    func inactiveContext() {
        var state = ARAMState()
        #expect(shake(&state, at: 0, active: false) == .ignored)
        #expect(shake(&state, at: 1, foreground: false) == .ignored)
        #expect(state.phase == .idle)
        #expect(state.session == nil)
        #expect(shake(&state, at: 1.1) == .opened)
    }

    @Test("Deferred draws cannot reopen a session in another tab or the background")
    func discardDeferredInInactiveContext() throws {
        for background in [true, false] {
            var state = ARAMState()
            shake(&state, at: 0)
            let identity = try #require(state.session?.id)
            state.close(sessionID: identity)
            shake(&state, at: 0.35)
            state.presentationDidDismiss(
                sessionID: identity,
                isActive: background,
                sceneIsActive: !background
            )
            #expect(state.session == nil)
            #expect(state.pendingChampionID == nil)
            #expect(state.phase == .idle)
        }
    }

    @Test("A deferred manual-gallery draw is discarded after switching tabs")
    func inactiveManualGallery() {
        var state = ARAMState()
        state.setGalleryPresented(true)
        shake(&state, at: 0)
        state.setGalleryPresented(false, isActive: false)
        #expect(state.session == nil)
        #expect(state.pendingChampionID == nil)
    }

    @Test("Empty catalogs do not start a cooldown or presentation")
    func emptyCatalog() {
        var state = ARAMState()
        #expect(shake(&state, at: 0, candidates: []) == .ignored)
        #expect(state.session == nil)
        #expect(shake(&state, at: 0.05) == .opened)
    }

    @Test("A singleton still supports repeated shakes")
    func singleton() {
        var state = ARAMState()
        #expect(shake(&state, at: 0, candidates: ["Ahri"], currentID: "Ahri") == .opened)
        #expect(shake(&state, at: 0.35, candidates: ["Ahri"]) == .replaced)
        #expect(state.session?.championID == "Ahri")
        #expect(state.session?.revision == 2)
    }

    @Test("Each accepted gesture invokes the selector exactly once")
    func oneDrawPerGesture() {
        var state = ARAMState()
        var draws = 0
        let eventID = UUID()
        for (time, id) in [(0.0, eventID), (0.35, eventID), (0.4, UUID())] {
            state.receiveShake(
                eventID: id, timestamp: time, isActive: true, sceneIsActive: true,
                candidateIDs: champions
            ) { _ in
                draws += 1
                return 0
            }
        }
        #expect(draws == 2)
        #expect(state.session?.revision == 2)
    }

    @Test("Closing cancels a pending gallery draw until another gesture arrives")
    func explicitCloseOverridesPendingDraw() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let identity = try #require(state.session?.id)
        state.setGalleryPresented(true, sessionID: identity)
        shake(&state, at: 0.35)
        #expect(state.pendingChampionID != nil)
        state.close(sessionID: identity)
        #expect(state.pendingChampionID == nil)
        state.presentationDidDismiss(sessionID: identity, isActive: true, sceneIsActive: true)
        #expect(state.phase == .idle)
        #expect(state.session == nil)
    }

    @Test("Selection uses unique valid IDs and avoids the current champion when possible")
    func selectionCandidates() {
        var state = ARAMState()
        var selectableCount = 0
        let result = state.receiveShake(
            eventID: UUID(), timestamp: 0, isActive: true, sceneIsActive: true,
            candidateIDs: ["", "Ahri", "Ahri", "Aatrox", "Ashe"],
            currentChampionID: "Ahri"
        ) { count in
            selectableCount = count
            return count - 1
        }
        #expect(result == .opened)
        #expect(selectableCount == 2)
        #expect(state.session?.championID == "Ashe")
    }

    @Test("Late gallery callbacks from a closed session cannot mutate its successor")
    func staleGalleryCallbacks() throws {
        var state = ARAMState()
        shake(&state, at: 0)
        let oldID = try #require(state.session?.id)
        state.close(sessionID: oldID)
        shake(&state, at: 0.35)
        state.presentationDidDismiss(sessionID: oldID, isActive: true, sceneIsActive: true)
        let current = state.session
        state.setGalleryPresented(true, sessionID: oldID)
        state.setGalleryPresented(false, sessionID: oldID)
        #expect(!state.isGalleryPresented)
        #expect(state.session == current)
    }

    @Test("Invalid time and selector input cannot corrupt presentation state")
    func invalidInput() {
        var state = ARAMState()
        #expect(shake(&state, at: .nan) == .ignored)
        let result = state.receiveShake(
            eventID: UUID(), timestamp: 0, isActive: true, sceneIsActive: true,
            candidateIDs: champions, selectIndex: { _ in -1 }
        )
        #expect(result == .ignored)
        #expect(state.session == nil)
        #expect(shake(&state, at: 0) == .opened)
    }
}
