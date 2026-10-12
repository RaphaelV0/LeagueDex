import Foundation

/// Version intentionally pinned until a catalog migration is explicitly validated.
/// Keeping model image URLs and imported Firestore content on the same patch prevents
/// mixing images for a recent patch with statistics from an older patch.
enum DataDragon {
    static let version = "14.18.1"
    static let locale = "fr_FR"
    static let baseURL = "https://ddragon.leagueoflegends.com"

    static func catalogURL(_ file: String) -> URL? {
        URL(string: "\(baseURL)/cdn/\(version)/data/\(locale)/\(file)")
    }

    static func imageURL(_ path: String) -> URL? {
        URL(string: "\(baseURL)/cdn/\(version)/img/\(path)")
    }
}
