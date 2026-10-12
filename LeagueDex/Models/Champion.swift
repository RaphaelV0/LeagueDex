import Foundation

// MARK: - 1. MODÈLE FIREBASE (CLOUD)
struct DBChampion: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var title: String
    var blurb: String
    var tags: [String]
    
    // Statistiques de base et évolution
    var hp: Double; var hpperlevel: Double
    var mp: Double; var mpperlevel: Double
    var armor: Double; var armorperlevel: Double
    var spellblock: Double; var spellblockperlevel: Double
    var attackdamage: Double; var attackdamageperlevel: Double
    var attackspeed: Double; var attackspeedperlevel: Double
    var crit: Double; var critperlevel: Double
    var movespeed: Double
    
    // Données chargées à la demande
    var isDetailLoaded: Bool = false
    var allyTips: [String] = []
    var enemyTips: [String] = []
    var skins: [DBSkin] = []
    var spells: [DBSpell] = []
    var passiveName: String = ""
    var passiveDesc: String = ""
    var passiveImage: String = ""
    var fullLore: String = ""
    
    // Données utilisateur
    var isFavorite: Bool = false
    
    // Propriétés calculées (Images)
    var iconURL: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/\(DataDragon.version)/img/champion/\(id).png") }
    var splashArtURL: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/\(id)_0.jpg") }
    
    // Fonction mathématique intégrée au modèle
    func statAt(base: Double, growth: Double, level: Int) -> Double {
        if level == 1 { return base }
        let n = Double(level - 1)
        return base + (growth * (n * (0.7025 + 0.0175 * n)))
    }
}

// Structures imbriquées pour DBChampion
struct DBSkin: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let num: Int
    var url: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/\(championId)_\(num).jpg") }
    let championId: String
}

struct DBSpell: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let desc: String
    var url: URL? { URL(string: "https://ddragon.leagueoflegends.com/cdn/\(DataDragon.version)/img/spell/\(id).png") }
}

// MARK: - 2. MODÈLES API (RIOT GAMES)
struct APIResponse: Codable { let data: [String: APIChampion] }

struct APIChampion: Codable {
    let id: String; let name: String; let title: String; let blurb: String; let tags: [String]
    let stats: APIStats
}

struct APIStats: Codable {
    let hp: Double; let hpperlevel: Double; let mp: Double; let mpperlevel: Double
    let armor: Double; let armorperlevel: Double; let spellblock: Double; let spellblockperlevel: Double
    let attackdamage: Double; let attackdamageperlevel: Double; let attackspeed: Double; let attackspeedperlevel: Double
    let crit: Double; let critperlevel: Double
    let movespeed: Double
}

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
