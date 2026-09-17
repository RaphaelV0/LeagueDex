//
//  ChampionViewModel.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ChampionViewModel: ObservableObject {
    @Published var champions: [DBChampion] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        fetchChampionsFromFirebase()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    // 1. Écoute Firebase en temps réel
    func fetchChampionsFromFirebase() {
        isLoading = true
        listenerRegistration = db.collection("champions").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Erreur Firestore: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.champions = documents.compactMap { try? $0.data(as: DBChampion.self) }
            self.champions.sort { $0.name < $1.name }
            self.isLoading = false
            
            // Si la base cloud est vide, on télécharge depuis Riot
            if self.champions.isEmpty {
                Task { await self.syncChampionsFromRiot() }
            }
        }
    }
    
    // 2. Télécharge depuis Riot et pousse sur Firebase
    private func syncChampionsFromRiot() async {
        guard let url = URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/data/fr_FR/champion.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            
            let batch = db.batch()
            
            for apiChamp in response.data.values {
                let dbChamp = DBChampion(
                    id: apiChamp.id, name: apiChamp.name, title: apiChamp.title, blurb: apiChamp.blurb, tags: apiChamp.tags,
                    hp: apiChamp.stats.hp, hpperlevel: apiChamp.stats.hpperlevel, mp: apiChamp.stats.mp, mpperlevel: apiChamp.stats.mpperlevel,
                    armor: apiChamp.stats.armor, armorperlevel: apiChamp.stats.armorperlevel, spellblock: apiChamp.stats.spellblock,
                    spellblockperlevel: apiChamp.stats.spellblockperlevel, attackdamage: apiChamp.stats.attackdamage, attackdamageperlevel: apiChamp.stats.attackdamageperlevel,
                    attackspeed: apiChamp.stats.attackspeed, attackspeedperlevel: apiChamp.stats.attackspeedperlevel, crit: apiChamp.stats.crit, critperlevel: apiChamp.stats.critperlevel, movespeed: apiChamp.stats.movespeed
                )
                
                let docRef = db.collection("champions").document(dbChamp.id)
                try batch.setData(from: dbChamp, forDocument: docRef)
            }
            try await batch.commit()
            print("Importation Riot -> Firebase (Champions) terminée avec succès.")
        } catch {
            print("Erreur d'importation : \(error)")
        }
    }
    
    // 3. Charge les détails du champion (Sorts, Skins) et met à jour Firebase
    func loadDetails(for champion: DBChampion) async {
        if champion.isDetailLoaded { return }
        guard let url = URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/data/fr_FR/champion/\(champion.id).json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIDetailResponse.self, from: data)
            
            if let details = response.data[champion.id] {
                var updatedChamp = champion
                updatedChamp.allyTips = details.allytips
                updatedChamp.enemyTips = details.enemytips
                updatedChamp.skins = details.skins.map { DBSkin(name: $0.name, num: $0.num, championId: champion.id) }
                updatedChamp.spells = details.spells.map { DBSpell(id: $0.id, name: $0.name, desc: $0.description) }
                updatedChamp.passiveName = details.passive.name
                updatedChamp.passiveDesc = details.passive.description
                updatedChamp.passiveImage = details.passive.image.full
                updatedChamp.fullLore = details.lore
                updatedChamp.isDetailLoaded = true
                
                try db.collection("champions").document(champion.id).setData(from: updatedChamp)
            }
        } catch {
            print("Erreur de chargement des détails : \(error)")
        }
    }
    
    // 4. Modifie les favoris dans le cloud
    func toggleFavorite(for champion: DBChampion) {
        var updatedChamp = champion
        updatedChamp.isFavorite.toggle()
        try? db.collection("champions").document(champion.id).setData(from: updatedChamp)
    }
}