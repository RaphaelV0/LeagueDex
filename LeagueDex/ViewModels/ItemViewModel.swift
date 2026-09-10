//
//  ItemViewModel.swift
//  LeagueDex
//
//  Created by Etudiant on 10/09/2026.
//


import SwiftUI
import SwiftData
import Combine

@MainActor
class ItemViewModel: ObservableObject {
    @Published var isLoading = false
    
    func syncItems(context: ModelContext) async {
        isLoading = true
        guard let url = URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/data/fr_FR/item.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIItemResponse.self, from: data)
            
            for (key, apiItem) in response.data {
                // On exclut les objets qui ne coûtent rien (souvent des objets internes/cachés du jeu)
                guard apiItem.gold.total > 0 else { continue }
                
                let dbItem = DBItem(
                    id: key,
                    name: apiItem.name,
                    plaintext: apiItem.plaintext,
                    itemDescription: apiItem.description,
                    baseCost: apiItem.gold.base,
                    totalCost: apiItem.gold.total,
                    sellPrice: apiItem.gold.sell
                )
                context.insert(dbItem)
            }
            try context.save()
        } catch {
            print("Erreur réseau Objets: \(error)")
        }
        isLoading = false
    }
}
