//
//  DBItem.swift
//  LeagueDex
//
//  Created by Etudiant on 10/09/2026.
//


import Foundation
import SwiftData

// MARK: - Modèle Base de Données (SwiftData)
@Model
class DBItem {
    @Attribute(.unique) var id: String // L'API utilise un ID numérique sous forme de texte (ex: "1001")
    var name: String
    var plaintext: String // Petit résumé
    var itemDescription: String // Les stats complètes (contient des balises HTML)
    var baseCost: Int
    var totalCost: Int
    var sellPrice: Int
    
    init(id: String, name: String, plaintext: String, itemDescription: String, baseCost: Int, totalCost: Int, sellPrice: Int) {
        self.id = id
        self.name = name
        self.plaintext = plaintext
        self.itemDescription = itemDescription
        self.baseCost = baseCost
        self.totalCost = totalCost
        self.sellPrice = sellPrice
    }
    
    // Raccourci pour l'icône de l'objet
    var iconURL: URL? {
        URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/img/item/\(id).png")
    }
}

// MARK: - Modèles API (Internet)
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