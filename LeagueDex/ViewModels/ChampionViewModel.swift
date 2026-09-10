import SwiftUI
import SwiftData
import Combine

@MainActor
class ChampionViewModel: ObservableObject {
    @Published var isLoading = false
    
    // Télécharge la liste de base
    func syncChampions(context: ModelContext) async {
        isLoading = true
        guard let url = URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/data/fr_FR/champion.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            
            for apiChamp in response.data.values {
                let dbChamp = DBChampion(
                    id: apiChamp.id, name: apiChamp.name, title: apiChamp.title, blurb: apiChamp.blurb, tags: apiChamp.tags,
                    hp: apiChamp.stats.hp, hpperlevel: apiChamp.stats.hpperlevel, mp: apiChamp.stats.mp, mpperlevel: apiChamp.stats.mpperlevel,
                    armor: apiChamp.stats.armor, armorperlevel: apiChamp.stats.armorperlevel, spellblock: apiChamp.stats.spellblock,
                    spellblockperlevel: apiChamp.stats.spellblockperlevel, attackdamage: apiChamp.stats.attackdamage,
                    attackdamageperlevel: apiChamp.stats.attackdamageperlevel, attackspeed: apiChamp.stats.attackspeed, attackspeedperlevel: apiChamp.stats.attackspeedperlevel,
                    crit: apiChamp.stats.crit, critperlevel: apiChamp.stats.critperlevel, // <-- NOUVEAU
                    movespeed: apiChamp.stats.movespeed // <-- NOUVEAU
                )
                context.insert(dbChamp)
            }
            try context.save()
        } catch {
            print("Erreur réseau: \(error)")
        }
        isLoading = false
    }
    
    // Télécharge les détails spécifiques d'un champion
    func loadDetails(for champion: DBChampion, context: ModelContext) async {
        if champion.isDetailLoaded { return }
        
        guard let url = URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/data/fr_FR/champion/\(champion.id).json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIDetailResponse.self, from: data)
            
            if let details = response.data[champion.id] {
                champion.allyTips = details.allytips
                champion.enemyTips = details.enemytips
                champion.skins = details.skins.map { DBSkin(name: $0.name, num: $0.num, championId: champion.id) }
                champion.spells = details.spells.map { DBSpell(id: $0.id, name: $0.name, desc: $0.description) }
                champion.passiveName = details.passive.name
                champion.passiveDesc = details.passive.description
                champion.passiveImage = details.passive.image.full
                champion.fullLore = details.lore
                champion.isDetailLoaded = true
                
                try context.save()
            }
        } catch {
            print("Erreur lors du chargement des détails : \(error)")
        }
    }
}
