import Foundation

/// An inventory preserves each occupied slot, including repeated item IDs.
/// Missing catalog entries are explicit: their unknown prices never become zero.
struct BuildInventory {
    static let maximumSlots = 6
    private(set) var itemIDs: [String]

    init(itemIDs: [String] = []) { self.itemIDs = itemIDs }

    var canAddItem: Bool { itemIDs.count < Self.maximumSlots }
    var isValid: Bool { itemIDs.count <= Self.maximumSlots && !itemIDs.contains(where: \.isEmpty) }

    @discardableResult
    mutating func add(_ id: String) -> Bool {
        guard canAddItem, !id.isEmpty else { return false }
        itemIDs.append(id)
        return true
    }

    mutating func remove(at index: Int) {
        guard itemIDs.indices.contains(index) else { return }
        itemIDs.remove(at: index)
    }

    struct Cost: Equatable {
        let knownSubtotal: Int
        let missingItemIDs: [String]
        var isComplete: Bool { missingItemIDs.isEmpty }
    }

    func cost(prices: [String: Int]) -> Cost {
        var subtotal = 0
        var missing: [String] = []
        for id in itemIDs {
            guard let price = prices[id], price >= 0 else {
                if !missing.contains(id) { missing.append(id) }
                continue
            }
            subtotal += price
        }
        return Cost(knownSubtotal: subtotal, missingItemIDs: missing)
    }
}
