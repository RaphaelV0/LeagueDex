import Foundation

/// Favorites are device-specific, not shared champion catalog fields.
/// Existing Firestore favorites are imported once per device for backwards compatibility.
@MainActor
final class FavoritesStore {
    static let shared = FavoritesStore()
    private let defaults = UserDefaults.standard
    private let favoritesKey = "LeagueDex.favoriteChampionIDs.v1"
    private let migrationKey = "LeagueDex.favoritesMigrated.v1"
    private(set) var ids: Set<String>

    private init() {
        ids = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
    }

    func migrateIfNeeded(_ champions: [DBChampion]) {
        guard !defaults.bool(forKey: migrationKey), !champions.isEmpty else { return }
        ids.formUnion(champions.filter(\.isFavorite).map(\.id))
        persist()
        defaults.set(true, forKey: migrationKey)
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if !ids.insert(id).inserted { ids.remove(id) }
        persist()
    }

    private func persist() {
        defaults.set(ids.sorted(), forKey: favoritesKey)
    }
}
