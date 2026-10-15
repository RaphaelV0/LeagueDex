import Foundation
import Combine

/// The full pinned Riot roster is the daily authority, independent of a partial
/// Firestore result. A cached roster can restore the same daily identity offline.
@MainActor
final class DailyChampionStore: ObservableObject {
    @Published private(set) var champion: DBChampion?
    @Published private(set) var question: QuizQuestion?
    @Published private(set) var dayKey = DailySelection.dayKey(for: Date())
    @Published private(set) var isLoading = false
    @Published private(set) var isFromCache = true
    @Published private(set) var errorMessage: String?

    private var roster: [APIChampion] = []
    private var loadTask: Task<Void, Never>?
    private var didAttemptNetwork = false

    deinit { loadTask?.cancel() }

    func refresh(for date: Date = Date(), force: Bool = false) async {
        applyRoster(for: date)
        if let loadTask { await loadTask.value; return }
        guard force || !didAttemptNetwork else { return }
        isLoading = champion == nil
        errorMessage = nil
        let task = Task { [weak self] in
            if let cached = try? await DataDragon.fetch(APIResponse.self, file: "champion.json", cachedOnly: true,
                                                       validate: Self.validate) {
                guard let self, !Task.isCancelled else { return }
                self.roster = Array(cached.value.data.values)
                self.isFromCache = true
                self.applyRoster(for: Date())
                self.isLoading = false
            }
            do {
                let result = try await DataDragon.fetch(APIResponse.self, file: "champion.json", validate: Self.validate)
                try Task.checkCancellation()
                guard let self else { return }
                self.roster = Array(result.value.data.values)
                self.isFromCache = result.isFromCache
                self.applyRoster(for: Date())
                self.errorMessage = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                if self.roster.isEmpty {
                    self.errorMessage = "Le champion du jour nécessite un premier téléchargement du catalogue Riot."
                }
            }
            guard let self else { return }
            self.isLoading = false
            self.didAttemptNetwork = true
            self.loadTask = nil
        }
        loadTask = task
        await task.value
    }

    private static func validate(_ response: APIResponse) throws {
        guard !response.data.isEmpty, response.data.count <= 500,
              response.data.allSatisfy({ $0.key == $0.value.id && !$0.value.name.isEmpty }) else {
            throw URLError(.cannotParseResponse)
        }
    }

    private func applyRoster(for date: Date) {
        dayKey = DailySelection.dayKey(for: date)
        guard let id = DailySelection.championID(in: roster.map(\.id), dayKey: dayKey),
              let api = roster.first(where: { $0.id == id }) else { return }
        let champion = DBChampion(
            id: api.id, name: api.name, title: api.title, blurb: api.blurb, tags: api.tags,
            hp: api.stats.hp, hpperlevel: api.stats.hpperlevel, mp: api.stats.mp, mpperlevel: api.stats.mpperlevel,
            armor: api.stats.armor, armorperlevel: api.stats.armorperlevel, spellblock: api.stats.spellblock,
            spellblockperlevel: api.stats.spellblockperlevel, attackdamage: api.stats.attackdamage,
            attackdamageperlevel: api.stats.attackdamageperlevel, attackspeed: api.stats.attackspeed,
            attackspeedperlevel: api.stats.attackspeedperlevel, crit: api.stats.crit,
            critperlevel: api.stats.critperlevel, movespeed: api.stats.movespeed
        )
        self.champion = champion
        question = QuizEngine.dailyQuestion(champions: roster.map { api in
            QuizChampionSnapshot(id: api.id, name: api.name, title: api.title, description: api.blurb,
                roles: api.tags, spells: [], health: api.stats.hp, armor: api.stats.armor, attackDamage: api.stats.attackdamage)
        }, dayKey: dayKey)
    }
}
