import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// A document per champion prevents replacing another device's whole collection.
/// False tombstones also prevent a legacy import from resurrecting removals.
@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    @Published private(set) var ids: Set<String> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isFromCache = true
    @Published private(set) var hasPendingWrites = false
    private let defaults = UserDefaults.standard
    private let legacyKey = "LeagueDex.favoriteChampionIDs.v1"
    private var uid: String?
    private var listener: ListenerRegistration?
    private var migrating = false
    private var generation = UUID()

    private init() {}

    func bind(uid: String?) {
        guard self.uid != uid else { return }
        listener?.remove()
        generation = UUID()
        migrating = false
        self.uid = uid
        ids = []
        errorMessage = nil
        hasPendingWrites = false
        isFromCache = true
        guard let uid else { return }
        let token = generation
        listener = Firestore.firestore().collection("users").document(uid).collection("favorites")
            .addSnapshotListener(includeMetadataChanges: true) { @Sendable [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if error != nil {
                        self.errorMessage = "La synchronisation des favoris est indisponible."
                        return
                    }
                    guard let snapshot else { return }
                    self.ids = Set(snapshot.documents.filter { $0.data()["selected"] as? Bool == true }.map(\.documentID))
                    self.isFromCache = snapshot.metadata.isFromCache
                    self.hasPendingWrites = snapshot.metadata.hasPendingWrites
                    self.errorMessage = nil
                    if !snapshot.metadata.isFromCache { self.importLegacyIfNeeded() }
                }
            }
    }

    /// The original backup is never deleted. Only its first authenticated owner imports it.
    func migrateIfNeeded(_ champions: [DBChampion]) {
        // Old shared catalog flags have no author uid and cannot be attributed
        // safely. Only this device's existing local backup is imported.
        importLegacyIfNeeded()
    }

    private func importLegacyIfNeeded() {
        guard let uid, Auth.auth().currentUser?.uid == uid, !migrating,
              defaults.string(forKey: "LeagueDex.legacyFavoritesOwner.v2") == nil else { return }
        let claimant = defaults.string(forKey: "LeagueDex.legacyFavoritesClaim.v2")
        guard claimant == nil || claimant == uid else { return }
        let legacy = Set(defaults.stringArray(forKey: legacyKey) ?? []).filter { !$0.isEmpty && !$0.contains("/") }
        guard !legacy.isEmpty else { return }
        // Reserve the backup before I/O so switching accounts during a transaction
        // cannot import this account's legacy data into the next account.
        defaults.set(uid, forKey: "LeagueDex.legacyFavoritesClaim.v2")
        migrating = true
        let token = generation
        let user = Firestore.firestore().collection("users").document(uid)
        Firestore.firestore().runTransaction({ @Sendable transaction, errorPointer -> Any? in
            do {
                var missing: [DocumentReference] = []
                for id in legacy {
                    let ref = user.collection("favorites").document(id)
                    if !(try transaction.getDocument(ref)).exists { missing.append(ref) }
                }
                for ref in missing {
                    transaction.setData(["championID": ref.documentID, "selected": true,
                                         "updatedAt": FieldValue.serverTimestamp()], forDocument: ref)
                }
                return nil
            } catch { errorPointer?.pointee = error as NSError; return nil }
        }) { @Sendable [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.migrating = false
                if error == nil {
                    self.defaults.set(uid, forKey: "LeagueDex.legacyFavoritesOwner.v2")
                } else {
                    self.errorMessage = "Favoris locaux conservés ; importation à reprendre avec une connexion."
                }
            }
        }
    }

    func isFavorite(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        guard let uid, Auth.auth().currentUser?.uid == uid else { return }
        let selected = !ids.contains(id)
        if selected { ids.insert(id) } else { ids.remove(id) }
        hasPendingWrites = true
        let token = generation
        Firestore.firestore().collection("users").document(uid).collection("favorites").document(id)
            .setData(["championID": id, "selected": selected, "updatedAt": FieldValue.serverTimestamp()]) { @Sendable [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if error != nil { self.errorMessage = "Modification du favori refusée par Firebase." }
                }
            }
    }
}
