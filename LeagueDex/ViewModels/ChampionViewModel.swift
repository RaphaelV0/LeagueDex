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
    @Published private(set) var detailErrors: [String: String] = [:]
    @Published private(set) var detailLoadingIDs = Set<String>()

    // The model owns these requests, rather than a detail view's cancellable .task.
    // Returning to a champion shares the existing request and its in-memory result.
    private var detailTasks: [String: Task<Void, Never>] = [:]
    private var detailsCache: [String: ChampionDetails] = [:]
    private var importTask: Task<Void, Never>?
    private var isImporting = false
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        fetchChampionsFromFirebase()
    }
    
    deinit {
        listenerRegistration?.remove()
        detailTasks.values.forEach { $0.cancel() }
        importTask?.cancel()
    }
    
    // 1. Écoute Firebase en temps réel
    func fetchChampionsFromFirebase() {
        listenerRegistration?.remove()
        errorMessage = nil
        isLoading = true
        listenerRegistration = db.collection("champions").addSnapshotListener(includeMetadataChanges: true) { @Sendable [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                self?.receiveSnapshot(snapshot, error: error)
            }
        }
    }

    private func receiveSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error {
            print("Erreur Firestore: \(error.localizedDescription)")
            errorMessage = "Impossible de charger les champions. Vérifiez votre connexion."
            isLoading = false
            return
        }

        guard let snapshot else {
            errorMessage = "Aucune réponse de la base de données."
            isLoading = false
            return
        }

        let documents = snapshot.documents
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
                // An offline snapshot or rejected write must not roll back successful
                // local downloads. Only detail fields are merged into current metadata.
                details.apply(to: &champion)
            } else if champion.isDetailLoaded {
                detailsCache[id] = ChampionDetails(champion: champion)
            }
            fetched.append(champion)
        }
        champions = fetched.sorted { $0.name < $1.name }
        errorMessage = decodingFailures == 0 ? nil : "Certains champions sont illisibles dans la base de données."
        isLoading = false

        // An empty local cache or documents that failed to decode are not an empty
        // database. Bootstrap only after the server has confirmed no documents exist.
        if documents.isEmpty && !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites && !isImporting {
            syncChampionsFromRiot()
        }
    }

    // 2. Télécharge depuis Riot et pousse sur Firebase
    private func syncChampionsFromRiot() {
        guard let url = DataDragon.catalogURL("champion.json") else { return }
        guard !isImporting else { return }
        isImporting = true
        let collection = db.collection("champions")
        importTask = Task { [weak self] in
            do {
                let data = try await Self.validatedData(from: url)
                try Task.checkCancellation()
                let response = try JSONDecoder().decode(APIResponse.self, from: data)
                guard !response.data.isEmpty, response.data.count <= 500 else {
                    throw URLError(.cannotParseResponse)
                }
                // A different client may have populated the catalog during the Riot
                // download. Check the server again before preparing any writes.
                let current = try await collection.limit(to: 1).getDocuments(source: .server)
                try Task.checkCancellation()
                guard let self else { return }
                guard current.documents.isEmpty, !current.metadata.isFromCache,
                      !current.metadata.hasPendingWrites else {
                    self.isImporting = false
                    self.importTask = nil
                    return
                }

                // Encoded immutable bytes can cross into Firestore's transaction
                // worker without capturing MainActor-isolated model instances.
                var encodedChampions: [String: Data] = [:]
                for apiChamp in response.data.values {
                    let dbChamp = DBChampion(
                        id: apiChamp.id, name: apiChamp.name, title: apiChamp.title, blurb: apiChamp.blurb, tags: apiChamp.tags,
                        hp: apiChamp.stats.hp, hpperlevel: apiChamp.stats.hpperlevel, mp: apiChamp.stats.mp, mpperlevel: apiChamp.stats.mpperlevel,
                        armor: apiChamp.stats.armor, armorperlevel: apiChamp.stats.armorperlevel, spellblock: apiChamp.stats.spellblock,
                        spellblockperlevel: apiChamp.stats.spellblockperlevel, attackdamage: apiChamp.stats.attackdamage, attackdamageperlevel: apiChamp.stats.attackdamageperlevel,
                        attackspeed: apiChamp.stats.attackspeed, attackspeedperlevel: apiChamp.stats.attackspeedperlevel, crit: apiChamp.stats.crit, critperlevel: apiChamp.stats.critperlevel, movespeed: apiChamp.stats.movespeed
                    )

                    encodedChampions[dbChamp.id] = try JSONEncoder().encode(dbChamp)
                }
                let records = encodedChampions
                // Read every target before any write. If another client creates a
                // champion between the server recheck and commit, abort or retry the
                // transaction rather than replacing its details, stats or favorites.
                db.runTransaction({ @Sendable transaction, errorPointer -> Any? in
                    do {
                        var writes: [(reference: DocumentReference, fields: [String: Any])] = []
                        for (id, bytes) in records {
                            let reference = collection.document(id)
                            guard !(try transaction.getDocument(reference)).exists else { return nil }
                            guard let fields = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
                                throw URLError(.cannotParseResponse)
                            }
                            writes.append((reference, fields))
                        }
                        for write in writes {
                            transaction.setData(write.fields, forDocument: write.reference)
                        }
                        return nil
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                }) { @Sendable [weak self] _, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isImporting = false
                        if let error {
                            self.errorMessage = "Importation des champions impossible. Réessayez plus tard."
                            print("Erreur d'importation : \(error)")
                        }
                    }
                }
                self.importTask = nil
            } catch {
                guard let self else { return }
                self.importTask = nil
                self.isImporting = false
                if !Task.isCancelled {
                    self.errorMessage = "Importation des champions impossible. Réessayez plus tard."
                    print("Erreur d'importation : \(error)")
                }
            }
        }
    }
    
    // 3. Charge les détails du champion (Sorts, Skins) et met à jour Firebase
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
                // Publish first. Reading the champion must never depend on write
                // permission, network connectivity, or the listener's next snapshot.
                self.persist(details, for: id)
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

    private func persist(_ details: ChampionDetails, for id: String) {
        db.collection("champions").document(id).updateData(details.firestoreFields) { @Sendable error in
            if let error {
                // The in-memory data stays usable even when Firestore is read-only.
                print("Détails de \(id) disponibles localement, synchronisation impossible : \(error)")
            }
        }
    }

    private static func downloadDetails(for id: String) async throws -> ChampionDetails {
        guard let url = DataDragon.catalogURL("champion/\(id).json") else {
            throw URLError(.badURL)
        }
        let data = try await validatedData(from: url)
        try Task.checkCancellation()
        let response = try JSONDecoder().decode(APIDetailResponse.self, from: data)
        guard let details = response.data[id] else {
            throw URLError(.cannotParseResponse)
        }
        return ChampionDetails(details: details, championID: id)
    }

    private static func validatedData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, timeoutInterval: 30)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
    
    // 4. Modifie uniquement les favoris locaux
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

    var firestoreFields: [String: Any] {
        [
            "allyTips": allyTips,
            "enemyTips": enemyTips,
            "skins": skins.map { ["name": $0.name, "num": $0.num, "championId": $0.championId] as [String: Any] },
            "spells": spells.map { ["id": $0.id, "name": $0.name, "desc": $0.desc] },
            "passiveName": passiveName,
            "passiveDesc": passiveDesc,
            "passiveImage": passiveImage,
            "fullLore": fullLore,
            "isDetailLoaded": true
        ]
    }
}
