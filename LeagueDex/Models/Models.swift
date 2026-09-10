import Foundation
import SwiftData

// MARK: - 1. MODÈLE DE LA BASE DE DONNÉES (HORS-LIGNE)
@Model
class DBChampion {
    @Attribute(.unique) var id: String
    var name: String
    var title: String
    var blurb: String
    var tags: [String]
    
    // Stats
    var hp: Double; var hpperlevel: Double
    var mp: Double; var mpperlevel: Double
    var armor: Double; var armorperlevel: Double
    var spellblock: Double; var spellblockperlevel: Double
    var attackdamage: Double; var attackdamageperlevel: Double
    var attackspeed: Double; var attackspeedperlevel: Double
    var crit: Double; var critperlevel: Double // <-- NOUVEAU
    var movespeed: Double // <-- NOUVEAU
    
    // Détails chargés à la demande
    var isDetailLoaded: Bool = false
    var allyTips: [String] = []
    var enemyTips: [String] = []
    var skins: [DBSkin] = []
    var spells: [DBSpell] = []
    var passiveName: String = ""
    var passiveDesc: String = ""
    var passiveImage: String = ""
    var isFavorite: Bool = false
    var fullLore: String = ""
    
    init(id: String, name: String, title: String, blurb: String, tags: [String], hp: Double, hpperlevel: Double, mp: Double, mpperlevel: Double, armor: Double, armorperlevel: Double, spellblock: Double, spellblockperlevel: Double, attackdamage: Double, attackdamageperlevel: Double, attackspeed: Double, attackspeedperlevel: Double, crit: Double, critperlevel: Double, movespeed: Double) {
        self.id = id; self.name = name; self.title = title; self.blurb = blurb; self.tags = tags
        self.hp = hp; self.hpperlevel = hpperlevel; self.mp = mp; self.mpperlevel = mpperlevel
        self.armor = armor; self.armorperlevel = armorperlevel; self.spellblock = spellblock
        self.spellblockperlevel = spellblockperlevel; self.attackdamage = attackdamage
        self.attackdamageperlevel = attackdamageperlevel; self.attackspeed = attackspeed; self.attackspeedperlevel = attackspeedperlevel
        self.crit = crit; self.critperlevel = critperlevel; self.movespeed = movespeed
    }
    
    // Raccourcis pour les images
    var iconURL: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/img/champion/\(id).png") }
    var splashArtURL: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/\(id)_0.jpg") }
    
    // Formule mathématique des stats
    func statAt(base: Double, growth: Double, level: Int) -> Double {
        if level == 1 { return base }
        let n = Double(level - 1)
        return base + (growth * (n * (0.7025 + 0.0175 * n)))
    }
}

// Structures imbriquées pour la BDD
struct DBSkin: Codable, Identifiable {
    var id: String { name }
    let name: String
    let num: Int
    var url: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/\(championId)_\(num).jpg") }
    let championId: String
}
struct DBSpell: Codable, Identifiable {
    let id: String
    let name: String
    let desc: String
    var url: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/14.18.1/img/spell/\(id).png") }
}

// MARK: - 2. MODÈLES DE L'API (INTERNET)
struct APIResponse: Codable { let data: [String: APIChampion] }
struct APIChampion: Codable {
    let id: String; let name: String; let title: String; let blurb: String; let tags: [String]
    let stats: APIStats
}
struct APIStats: Codable {
    let hp: Double; let hpperlevel: Double; let mp: Double; let mpperlevel: Double
    let armor: Double; let armorperlevel: Double; let spellblock: Double; let spellblockperlevel: Double
    let attackdamage: Double; let attackdamageperlevel: Double; let attackspeed: Double; let attackspeedperlevel: Double
    let crit: Double; let critperlevel: Double // <-- NOUVEAU
    let movespeed: Double // <-- NOUVEAU
}

// Pour les détails spécifiques d'un champion
struct APIDetailResponse: Codable { let data: [String: APIDetail] }
struct APIDetail: Codable {
    let allytips: [String]; let enemytips: [String]
    let skins: [APISkin]
    let spells: [APISpell]
    let passive: APIPassive
    let lore: String
}
struct APISkin: Codable { let name: String; let num: Int }
struct APISpell: Codable { let id: String; let name: String; let description: String }
struct APIPassive: Codable { let name: String; let description: String; let image: APIImage }
struct APIImage: Codable { let full: String }
