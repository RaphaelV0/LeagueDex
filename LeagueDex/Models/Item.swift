import Foundation

// MARK: - 1. MODÈLE FIREBASE (CLOUD)
struct DBItem: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var plaintext: String
    var itemDescription: String
    var baseCost: Int
    var totalCost: Int
    var sellPrice: Int
    
    var iconURL: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/img/item/\(id).png") }
}

// MARK: - 2. MODÈLES API (RIOT GAMES)
struct APIItemResponse: Codable {
    let data: [String: APIItem]
}

struct APIItem: Codable {
    let name: String
    let plaintext: String
    let description: String
    let gold: APIItemGold
}

struct APIItemGold: Codable {
    let base: Int
    let total: Int
    let sell: Int
}
