import Testing
@testable import CompanionCore

@Suite("Champion comparison and six-slot inventory")
struct CompanionCoreTests {
    @Test("Level one and eighteen retain the catalog's established curve")
    func statEndpoints() {
        #expect(StatGrowth.value(base: 600, growth: 100, level: 1) == 600)
        #expect(StatGrowth.value(base: 600, growth: 100, level: 18) == 2300)
        #expect(abs(StatGrowth.value(base: 600, growth: 100, level: 2) - 672) < 0.0001)
    }

    @Test("Imported levels cannot escape the supported champion level range")
    func statBounds() {
        #expect(StatGrowth.value(base: 55, growth: 3, level: -7) == 55)
        #expect(StatGrowth.value(base: 55, growth: 3, level: 99) == 106)
        #expect(StatGrowth.value(base: 350, growth: 0, level: 18) == 350)
    }

    @Test("Repeated items occupy separate slots and each contributes its real price")
    func repeatedItems() {
        let inventory = BuildInventory(itemIDs: ["sword", "sword", "boots"])
        let cost = inventory.cost(prices: ["sword": 350, "boots": 300])
        #expect(cost.knownSubtotal == 1000)
        #expect(cost.isComplete)
        #expect(inventory.itemIDs.count == 3)
    }

    @Test("Unavailable items prevent a misleading total while preserving known prices")
    func unavailableItems() {
        let inventory = BuildInventory(itemIDs: ["sword", "retired", "retired", "invalid"])
        let cost = inventory.cost(prices: ["sword": 350, "invalid": -1])
        #expect(cost.knownSubtotal == 350)
        #expect(cost.missingItemIDs == ["retired", "invalid"])
        #expect(!cost.isComplete)
    }

    @Test("A seventh item is refused and removing one slot permits a replacement")
    func slotLimit() {
        var inventory = BuildInventory()
        for _ in 0..<6 { #expect(inventory.add("sword")) }
        #expect(!inventory.add("boots"))
        #expect(inventory.itemIDs.count == 6)
        inventory.remove(at: 2)
        #expect(inventory.add("boots"))
        #expect(inventory.itemIDs.last == "boots")
        #expect(inventory.isValid)
    }

    @Test("Malformed saved inventories are preserved for correction and fail validation")
    func invalidInventory() {
        var inventory = BuildInventory(itemIDs: Array(repeating: "sword", count: 7))
        #expect(!inventory.isValid)
        inventory.remove(at: 6)
        #expect(inventory.isValid)
        #expect(!inventory.add(""))
        inventory.remove(at: -1)
        #expect(inventory.itemIDs.count == 6)
    }
}
