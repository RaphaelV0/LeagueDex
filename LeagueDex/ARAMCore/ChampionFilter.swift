import Foundation

/// The lightweight values required by catalog filtering; no Firebase or image
/// request is needed to filter or randomly select champions.
struct ChampionCandidate: Equatable, Sendable {
    let id: String
    let name: String
    let tags: [String]
    let isFavorite: Bool
}

struct ChampionFilter: Sendable {
    var searchText = ""
    var selectedRole = "Tous"
    var favoritesOnly = false
    var sortDescending = false

    func matches(_ champion: ChampionCandidate) -> Bool {
        let searchMatches = searchText.isEmpty
            || champion.name.localizedStandardContains(searchText)
        let roleMatches = selectedRole == "Tous" || champion.tags.contains(selectedRole)
        return searchMatches && roleMatches && (!favoritesOnly || champion.isFavorite)
    }

    func apply(to candidates: [ChampionCandidate]) -> [ChampionCandidate] {
        candidates.filter(matches).sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            if comparison == .orderedSame { return $0.id < $1.id }
            return sortDescending ? comparison == .orderedDescending : comparison == .orderedAscending
        }
    }
}
