//
//  ItemViewModel.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ItemViewModel: ObservableObject {
    @Published var items: [DBItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var isImporting = false
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        fetchItemsFromFirebase()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    func fetchItemsFromFirebase() {
        listenerRegistration?.remove()
        errorMessage = nil
        isLoading = true
        listenerRegistration = db.collection("items").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Erreur Firestore (Items): \(error.localizedDescription)")
                self.errorMessage = "Impossible de charger les objets. Vérifiez votre connexion."
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.errorMessage = "Aucune réponse de la base de données."
                self.isLoading = false
                return
            }
            
            self.errorMessage = nil
            self.items = documents.compactMap { try? $0.data(as: DBItem.self) }
            self.items.sort { $0.totalCost > $1.totalCost } // Du plus cher au moins cher
            self.isLoading = false
            
            if self.items.isEmpty && !self.isImporting {
                Task { await self.syncItemsFromRiot() }
            }
        }
    }
    
    private func syncItemsFromRiot() async {
        guard let url = DataDragon.catalogURL("item.json") else { return }
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIItemResponse.self, from: data)
            
            let batch = db.batch()
            
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
                
                let docRef = db.collection("items").document(dbItem.id)
                try batch.setData(from: dbItem, forDocument: docRef)
            }
            try await batch.commit()
            print("Importation Riot -> Firebase (Objets) terminée avec succès.")
        } catch {
            errorMessage = "Importation des objets impossible. Réessayez plus tard."
            print("Erreur réseau Objets: \(error)")
        }
    }
}