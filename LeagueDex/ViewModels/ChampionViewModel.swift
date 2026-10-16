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
    @Published var errorMessage: String?
    @Published private(set) var isFromCache = true
    private var favoritesSubscription: AnyCancellable?
    @Published private(set) var detailErrors: [String: String] = [:]
    @Published private(set) var detailLoadingIDs = Set<String>()

    // The model owns these requests, rather than a detail view's cancellable .task.
    // Returning to a champion shares the existing request and its in-memory result;
    // DataDragon also keeps validated downloads on disk across process restarts.
    private var detailTasks: [String: Task<Void, Never>] = [:]
    private var detailsCache: [String: ChampionDetails] = [:]
    private var fallbackTask: Task<Void, Never>?
    private var fallbackAllowsNetwork = false
    private var hasLoadedFallback = false
    private var fallbackGeneration = UUID()
    private var listenerGeneration = UUID()
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        favoritesSubscription = FavoritesStore.shared.$ids.sink { [weak self] ids in
            guard let self else { return }
            for index in self.champions.indices {
                self.champions[index].isFavorite = ids.contains(self.champions[index].id)
            }
        }
        fetchChampionsFromFirebase()
    }
    
    deinit {
        listenerRegistration?.remove()
        detailTasks.values.forEach { $0.cancel() }
        fallbackTask?.cancel()
    }
    
    // 1. Écoute Firebase en temps réel
    func fetchChampionsFromFirebase() {
        listenerRegistration?.remove()
        fallbackTask?.cancel()
        fallbackTask = nil
        hasLoadedFallback = false
        fallbackGeneration = UUID()
        listenerGeneration = UUID()
        let generation = listenerGeneration
        errorMessage = nil
        isLoading = true
        listenerRegistration = db.collection("champions").addSnapshotListener(includeMetadataChanges: true) { @Sendable [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self, self.listenerGeneration == generation else { return }
                self.receiveSnapshot(snapshot, error: error)
            }
        }
    }

    private func receiveSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            print("Erreur Firestore: \(error.localizedDescription)")
            errorMessage = "Impossible de charger les champions. Vérifiez votre connexion."
            if champions.isEmpty && !ConnectivityStore.shared.isOnline {
                loadRiotFallback(cachedOnly: true)
            } else {
                isLoading = false
            }
            return
        }

        guard let snapshot else {
            errorMessage = "Aucune réponse de la base de données."
            if champions.isEmpty && !ConnectivityStore.shared.isOnline {
                loadRiotFallback(cachedOnly: true)
            } else {
                isLoading = false
            }
            return
        }

        let documents = snapshot.documents
        if documents.isEmpty {
            // Firestore is authoritative while online: a temporarily empty
            // local snapshot must not be mistaken for an empty server catalog.
            // Never replace an empty online Firestore result with Data Dragon.
            if snapshot.metadata.isFromCache {
                if champions.isEmpty && !ConnectivityStore.shared.isOnline {
                    loadRiotFallback(cachedOnly: true)
                } else {
                    isLoading = champions.isEmpty && ConnectivityStore.shared.isOnline
                }
            } else {
                isLoading = false
                if champions.isEmpty {
                    errorMessage = "Aucun champion disponible dans Firebase. Vérifiez la collection champions."
                }
            }
            return
        }

        // A catalog appeared while a fallback was downloading. Its listener wins.
        fallbackTask?.cancel()
        fallbackTask = nil
        fallbackGeneration = UUID()
        hasLoadedFallback = false
        var decoded: [(document: QueryDocumentSnapshot, champion: DBChampion)] = []
        var decodingFailures = 0
        for document in documents {
            do {
                decoded.append((document, try document.data(as: DBChampion.self)))
            } catch {
                decodingFailures += 1
                print("Champion Firestore illisible (\(document.documentID)) : \(error)")
            }
        }
        FavoritesStore.shared.migrateIfNeeded(decoded.map { $0.champion })
        var fetched: [DBChampion] = []
        for row in decoded {
            var champion = row.champion
            let id = champion.id
            champion.isFavorite = FavoritesStore.shared.isFavorite(id)
            let isAuthoritative = !snapshot.metadata.isFromCache && !row.document.metadata.isFromCache
                && !row.document.metadata.hasPendingWrites
            if isAuthoritative && champion.isDetailLoaded {
                // Accept later server corrections. A session cache is a fallback for
                // incomplete/offline snapshots, never a permanent override of Firebase.
                detailsCache[id] = ChampionDetails(champion: champion)
                detailTasks.removeValue(forKey: id)?.cancel()
                detailLoadingIDs.remove(id)
                detailErrors[id] = nil
            } else if let details = detailsCache[id] {
                // An offline snapshot must not roll back successful
                // local downloads. Only detail fields are merged into current metadata.
                details.apply(to: &champion)
            } else if champion.isDetailLoaded {
                detailsCache[id] = ChampionDetails(champion: champion)
            }
            fetched.append(champion)
        }
        if !fetched.isEmpty {
            champions = fetched.sorted { $0.name < $1.name }
            isFromCache = snapshot.metadata.isFromCache
        }
        errorMessage = decodingFailures == 0 ? nil : "Certains champions sont illisibles dans la base de données."
        isLoading = false

    }

    // 2. Offline fallback only. While connected, Firestore is the sole source of
    // champion catalog records and no client may overwrite the shared collection.
    private func loadRiotFallback(cachedOnly: Bool) {
        // No Data Dragon replacement while Firestore is reachable.
        guard !ConnectivityStore.shared.isOnline, cachedOnly else {
            isLoading = false
            return
        }
        if hasLoadedFallback && (cachedOnly || fallbackAllowsNetwork) { isLoading = false; return }
        if fallbackTask != nil {
            guard !cachedOnly, !fallbackAllowsNetwork else { return }
            fallbackTask?.cancel()
        }
        fallbackAllowsNetwork = !cachedOnly
        fallbackGeneration = UUID()
        let generation = fallbackGeneration
        isLoading = champions.isEmpty
        fallbackTask = Task { [weak self] in
            do {
                let result = try await DataDragon.fetch(APIResponse.self, file: "champion.json", cachedOnly: cachedOnly) { response in
                    guard !response.data.isEmpty, response.data.count <= 500,
                          response.data.allSatisfy({ key, champion in key == champion.id && !champion.name.isEmpty }) else {
                        throw URLError(.cannotParseResponse)
                    }
                }
                try Task.checkCancellation()
                guard let self, self.fallbackGeneration == generation else { return }
                self.champions = result.value.data.values.map { apiChamp in
                    var champion = DBChampion(
                        id: apiChamp.id, name: apiChamp.name, title: apiChamp.title, blurb: apiChamp.blurb, tags: apiChamp.tags,
                        hp: apiChamp.stats.hp, hpperlevel: apiChamp.stats.hpperlevel, mp: apiChamp.stats.mp, mpperlevel: apiChamp.stats.mpperlevel,
                        armor: apiChamp.stats.armor, armorperlevel: apiChamp.stats.armorperlevel, spellblock: apiChamp.stats.spellblock,
                        spellblockperlevel: apiChamp.stats.spellblockperlevel, attackdamage: apiChamp.stats.attackdamage, attackdamageperlevel: apiChamp.stats.attackdamageperlevel,
                        attackspeed: apiChamp.stats.attackspeed, attackspeedperlevel: apiChamp.stats.attackspeedperlevel, crit: apiChamp.stats.crit, critperlevel: apiChamp.stats.critperlevel, movespeed: apiChamp.stats.movespeed
                    )

                    champion.isFavorite = FavoritesStore.shared.isFavorite(champion.id)
                    if let details = self.detailsCache[champion.id] {
                        details.apply(to: &champion)
                    }
                    return champion
                }.sorted { $0.name < $1.name }
                self.hasLoadedFallback = true
                self.isFromCache = result.isFromCache
                self.isLoading = false
                self.errorMessage = nil
                self.fallbackTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.fallbackGeneration == generation else { return }
                self.fallbackTask = nil
                self.isLoading = false
                self.errorMessage = "Les champions sont indisponibles. Connectez-vous à Internet puis réessayez."
            }
        }
    }
    
    // 3. Charge les détails du champion (Sorts, Skins) avec un cache disque Data Dragon.
    func loadDetails(for champion: DBChampion) async {
        guard !Task.isCancelled else { return }
        let id = champion.id
        if let details = detailsCache[id] {
            apply(details, to: id)
            return
        }
        let latestChampion = champions.first { $0.id == id } ?? champion
        if latestChampion.isDetailLoaded {
            detailsCache[id] = ChampionDetails(champion: latestChampion)
            return
        }
        if let task = detailTasks[id] {
            await task.value
            return
        }

        detailErrors[id] = nil
        detailLoadingIDs.insert(id)
        let task = Task { [weak self] in
            do {
                let details = try await Self.downloadDetails(for: id)
                try Task.checkCancellation()
                guard let self else { return }
                self.detailsCache[id] = details
                self.apply(details, to: id)
                self.finishLoadingDetails(for: id)
            } catch {
                guard let self else { return }
                self.finishLoadingDetails(for: id)
                if !Task.isCancelled {
                    self.detailErrors[id] = "Les détails sont indisponibles. Vérifiez votre connexion puis réessayez."
                    print("Erreur de chargement des détails de \(id) : \(error)")
                }
            }
        }
        detailTasks[id] = task
        await task.value
    }

    func detailError(for championID: String) -> String? {
        detailErrors[championID]
    }

    func isLoadingDetails(for championID: String) -> Bool {
        detailLoadingIDs.contains(championID)
    }

    private func finishLoadingDetails(for id: String) {
        detailTasks[id] = nil
        detailLoadingIDs.remove(id)
    }

    private func apply(_ details: ChampionDetails, to id: String) {
        guard let index = champions.firstIndex(where: { $0.id == id }) else { return }
        // Read the current row, never the stale copy passed by an older detail view:
        // catalog edits and local favorites can change while a request is running.
        var updatedChampion = champions[index]
        details.apply(to: &updatedChampion)
        if updatedChampion != champions[index] {
            champions[index] = updatedChampion
        }
    }

    private static func downloadDetails(for id: String) async throws -> ChampionDetails {
        let result = try await DataDragon.fetch(APIDetailResponse.self, file: "champion/\(id).json") { response in
            guard let details = response.data[id], !details.spells.isEmpty,
                  !details.passive.name.isEmpty else { throw URLError(.cannotParseResponse) }
        }
        try Task.checkCancellation()
        guard let details = result.value.data[id] else {
            throw URLError(.cannotParseResponse)
        }
        return ChampionDetails(details: details, championID: id)
    }

    // 4. Modifie uniquement les favoris du compte connecté.
    func toggleFavorite(for champion: DBChampion) {
        FavoritesStore.shared.toggle(champion.id)
        if let index = champions.firstIndex(where: { $0.id == champion.id }) {
            champions[index].isFavorite = FavoritesStore.shared.isFavorite(champion.id)
        }
    }
}

/// A detail-only payload prevents a delayed download from overwriting catalog
/// metadata, statistics, or local favorite changes captured before the request.
private struct ChampionDetails {
    let allyTips: [String]
    let enemyTips: [String]
    let skins: [DBSkin]
    let spells: [DBSpell]
    let passiveName: String
    let passiveDesc: String
    let passiveImage: String
    let fullLore: String

    init(champion: DBChampion) {
        allyTips = champion.allyTips
        enemyTips = champion.enemyTips
        skins = champion.skins
        spells = champion.spells
        passiveName = champion.passiveName
        passiveDesc = champion.passiveDesc
        passiveImage = champion.passiveImage
        fullLore = champion.fullLore
    }

    init(details: APIDetail, championID: String) {
        allyTips = details.allytips
        enemyTips = details.enemytips
        skins = details.skins.map { DBSkin(name: $0.name, num: $0.num, championId: championID) }
        spells = details.spells.map { DBSpell(id: $0.id, name: $0.name, desc: $0.description) }
        passiveName = details.passive.name
        passiveDesc = details.passive.description
        passiveImage = details.passive.image.full
        fullLore = details.lore
    }

    func apply(to champion: inout DBChampion) {
        champion.allyTips = allyTips
        champion.enemyTips = enemyTips
        champion.skins = skins
        champion.spells = spells
        champion.passiveName = passiveName
        champion.passiveDesc = passiveDesc
        champion.passiveImage = passiveImage
        champion.fullLore = fullLore
        champion.isDetailLoaded = true
    }

}
