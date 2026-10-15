import Testing
@testable import ARAMCore

@Suite("Champion catalog filtering")
struct ChampionFilterTests {
    private let candidates = [
        ChampionCandidate(id: "Zed", name: "Zed", tags: ["Assassin"], isFavorite: true),
        ChampionCandidate(id: "Ahri", name: "Ahri", tags: ["Mage", "Assassin"], isFavorite: true),
        ChampionCandidate(id: "Ashe", name: "Ashe", tags: ["Marksman", "Support"], isFavorite: false)
    ]

    @Test("Catalog filtering combines search, role, and local favorites")
    func combinedFilters() {
        let filter = ChampionFilter(searchText: "AH", selectedRole: "Mage", favoritesOnly: true)
        #expect(filter.apply(to: candidates).map(\.id) == ["Ahri"])
        #expect(ChampionFilter(selectedRole: "Marksman", favoritesOnly: true).apply(to: candidates).isEmpty)
    }

    @Test("The default filter includes the full catalog in name order")
    func defaultOrder() {
        #expect(ChampionFilter().apply(to: candidates).map(\.id) == ["Ahri", "Ashe", "Zed"])
        #expect(ChampionFilter(sortDescending: true).apply(to: candidates).map(\.id) == ["Zed", "Ashe", "Ahri"])
    }

    @Test("Multi-role champions remain present in each matching role")
    func roleMembership() {
        #expect(ChampionFilter(selectedRole: "Assassin").apply(to: candidates).map(\.id) == ["Ahri", "Zed"])
        #expect(ChampionFilter(selectedRole: "Support").apply(to: candidates).map(\.id) == ["Ashe"])
    }

    @Test("No search match produces an empty pool")
    func noMatch() {
        #expect(ChampionFilter(searchText: "inexistant").apply(to: candidates).isEmpty)
    }
}
