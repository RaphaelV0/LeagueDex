import Foundation
import Testing
@testable import ARAMCore

@Suite("ARAM shake-only champion selection")
struct ARAMStateTests {
    private let champions = ["Ahri", "Aatrox", "Ashe"]

    @discardableResult
    private func shake(
        _ state: inout ARAMState,
        at time: TimeInterval,
        id: UUID = UUID(),
        candidates: [String]? = nil,
        selectIndex: @escaping (Int) -> Int = { _ in 0 }
    ) -> ARAMState.ShakeResult {
        state.receiveShake(
            eventID: id,
            timestamp: time,
            candidateIDs: candidates ?? champions,
            selectIndex: selectIndex
        )
    }

    @Test("A first shake opens ARAM and the next shake replaces the champion")
    func firstAndNext() {
        var state = ARAMState()
        #expect(shake(&state, at: 0) == .opened)
        #expect(state.currentChampionID == "Ahri")
        #expect(shake(&state, at: 0.7) == .replaced)
        #expect(state.currentChampionID == "Aatrox")
        #expect(state.revision == 2)
    }

    @Test("Twenty distinct shakes always leave only the last champion")
    func twentyShakes() {
        var state = ARAMState()
        for index in 0..<20 {
            let previous = state.currentChampionID
            let result = shake(&state, at: Double(index))
            #expect(result == (index == 0 ? .opened : .replaced))
            if previous != nil {
                #expect(state.currentChampionID != previous)
            }
            #expect(state.revision == index + 1)
        }
        #expect(state.currentChampionID != nil)
    }

    @Test("One physical event cannot produce two draws")
    func duplicateEvent() {
        var state = ARAMState()
        let event = UUID()
        #expect(shake(&state, at: 0, id: event) == .opened)
        #expect(shake(&state, at: 1, id: event) == .ignored)
        #expect(state.revision == 1)
    }

    @Test("A quick duplicate notification is ignored, but a later shake works")
    func debounce() {
        var state = ARAMState()
        #expect(shake(&state, at: 10) == .opened)
        #expect(shake(&state, at: 10.10) == .ignored)
        #expect(shake(&state, at: 10.60) == .replaced)
        #expect(state.revision == 2)
    }

    @Test("Clock regression never blocks all future shakes")
    func clockRegression() {
        var state = ARAMState()
        // A stale event timestamp after a valid shake used to produce a
        // permanently negative elapsed interval, ignoring every later draw.
        #expect(shake(&state, at: 120) == .opened)
        #expect(shake(&state, at: 1) == .replaced)
        #expect(shake(&state, at: 1.1) == .ignored)
        #expect(shake(&state, at: 1.7) == .replaced)
        #expect(state.revision == 3)
    }

    @Test("Debounce does not swallow subsequent shakes a second apart")
    func separatedShakes() {
        var state = ARAMState()
        for index in 0..<8 {
            let result = shake(&state, at: Double(index) + 0.5)
            #expect(result == (index == 0 ? .opened : .replaced))
            #expect(state.revision == index + 1)
        }
    }

    @Test("An empty catalog does not consume a shake")
    func emptyCatalog() {
        var state = ARAMState()
        #expect(shake(&state, at: 0, candidates: []) == .ignored)
        #expect(shake(&state, at: 0.1) == .opened)
    }

    @Test("One available champion still supports rerolls")
    func singleton() {
        var state = ARAMState()
        #expect(shake(&state, at: 0, candidates: ["Ahri"]) == .opened)
        #expect(shake(&state, at: 1, candidates: ["Ahri"]) == .replaced)
        #expect(state.currentChampionID == "Ahri")
        #expect(state.revision == 2)
    }

    @Test("Duplicate and empty champion IDs do not bias the draw")
    func duplicateCandidates() {
        var state = ARAMState()
        var numberOfCandidates = 0
        #expect(shake(&state, at: 0,
            candidates: ["", "Ahri", "Ahri", "Lux", "Lux"],
            selectIndex: { count in numberOfCandidates = count; return 1 }
        ) == .opened)
        #expect(numberOfCandidates == 2)
        #expect(state.currentChampionID == "Lux")
        #expect(shake(&state, at: 1,
            candidates: ["Ahri", "Ahri", "Lux"],
            selectIndex: { count in numberOfCandidates = count; return 0 }
        ) == .replaced)
        #expect(numberOfCandidates == 1)
        #expect(state.currentChampionID == "Ahri")
    }

    @Test("An invalid selector or timestamp does not change the screen")
    func invalidInputs() {
        var state = ARAMState()
        #expect(shake(&state, at: .nan) == .ignored)
        #expect(shake(&state, at: 0, selectIndex: { _ in -1 }) == .ignored)
        #expect(state.currentChampionID == nil)
        #expect(shake(&state, at: 0) == .opened)
    }

    @Test("Closing clears the champion and allows a new first shake")
    func closeAndReopen() {
        var state = ARAMState()
        #expect(shake(&state, at: 0) == .opened)
        state.reset()
        #expect(state.currentChampionID == nil)
        #expect(state.revision == 0)
        #expect(shake(&state, at: 1) == .opened)
        #expect(state.revision == 1)
    }
}
