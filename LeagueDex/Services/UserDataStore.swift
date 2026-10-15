import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// A session owns all listeners. Cached snapshots and pending edits stay scoped to uid.
@MainActor
final class UserDataStore: ObservableObject {
    @Published private(set) var builds: [CustomBuild] = []
    @Published private(set) var comparisons: [SavedComparison] = []
    @Published private(set) var quizRuns: [QuizRun] = []
    @Published private(set) var isFromCache = true
    @Published private(set) var hasPendingWrites = false
    @Published private(set) var pendingBuildIDs: Set<String> = []
    @Published private(set) var conflictingBuildIDs: Set<String> = []
    @Published private(set) var conflictedBuilds: [CustomBuild] = []
    @Published var errorMessage: String?

    let uid: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var networkSubscription: AnyCancellable?
    private var pending: [String: CustomBuild] = [:]
    private var serverBuilds: [CustomBuild] = []
    private var metadata: [String: (cache: Bool, pending: Bool)] = [:]
    private var syncing: Set<String> = []
    private var retryTask: Task<Void, Never>?
    private static var activeSessionID: UUID?
    private let sessionID = UUID()
    private var isCurrentSession: Bool { Self.activeSessionID == sessionID && Auth.auth().currentUser?.uid == uid }
    private var user: DocumentReference { db.collection("users").document(uid) }
    private var outboxKey: String { "LeagueDex.buildOutbox.v1.\(uid)" }

    init(uid: String) {
        self.uid = uid
        Self.activeSessionID = sessionID
        if let data = UserDefaults.standard.data(forKey: outboxKey),
           let saved = try? JSONDecoder().decode([String: CustomBuild].self, from: data) { pending = saved }
        publishBuilds()
        observe("builds") { [weak self] snapshot in
            guard let self else { return }
            self.serverBuilds = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let name = d["name"] as? String, let championID = d["championID"] as? String,
                      let itemIDs = d["itemIDs"] as? [String], let revision = d["revision"] as? Int else { return nil }
                return CustomBuild(id: doc.documentID, name: name, championID: championID, itemIDs: itemIDs,
                                   revision: revision, deleted: d["deleted"] as? Bool ?? false,
                                   createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast,
                                   updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast,
                                   mutationID: d["mutationID"] as? String ?? "legacy-\(doc.documentID)")
            }
            self.publishBuilds()
        }
        observe("comparisons") { [weak self] snapshot in
            self?.comparisons = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let left = d["leftID"] as? String, let right = d["rightID"] as? String,
                      let level = d["level"] as? Int else { return nil }
                return SavedComparison(id: doc.documentID, leftID: left, rightID: right, level: level)
            }.sorted { $0.id < $1.id }
        }
        observe("quizRuns") { [weak self] snapshot in
            self?.quizRuns = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let category = d["category"] as? String, let difficulty = d["difficulty"] as? String,
                      let score = d["score"] as? Int, let correct = d["correct"] as? Int,
                      let total = d["total"] as? Int else { return nil }
                return QuizRun(id: doc.documentID, category: category, difficulty: difficulty, score: score,
                               correct: correct, total: total,
                               completedAt: (d["completedAt"] as? Timestamp)?.dateValue() ?? Date(),
                               dayKey: d["dayKey"] as? String ?? "")
            }.sorted { $0.completedAt > $1.completedAt }
        }
        networkSubscription = ConnectivityStore.shared.$isOnline.removeDuplicates().sink { [weak self] online in
            if online { self?.retryPendingBuilds() }
        }
    }

    deinit {
        listeners.forEach { $0.remove() }
        retryTask?.cancel()
    }

    private func observe(_ collection: String, receive: @escaping (QuerySnapshot) -> Void) {
        listeners.append(user.collection(collection).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self, self.isCurrentSession else { return }
                if error != nil { self.errorMessage = "Synchronisation indisponible. Les données en cache restent consultables." }
                guard let snapshot else { return }
                self.metadata[collection] = (snapshot.metadata.isFromCache, snapshot.metadata.hasPendingWrites)
                self.isFromCache = self.metadata.values.contains { $0.cache }
                self.hasPendingWrites = self.metadata.values.contains { $0.pending } || !self.pending.isEmpty
                receive(snapshot)
            }
        })
    }

    /// Offline edits retain their expected server revision; transactions refuse stale writes.
    func saveBuild(_ build: CustomBuild) {
        guard isCurrentSession else { return }
        let name = build.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !build.championID.isEmpty, build.itemIDs.count <= 6 else {
            errorMessage = "Choisissez un nom, un champion et six objets au maximum."
            return
        }
        var copy = build
        copy.name = name
        // Repeated edits while offline must keep the revision first read from the server.
        copy.revision = pending[build.id]?.revision ?? build.revision
        copy.predecessorMutationID = pending[build.id]?.predecessorMutationID
            ?? (syncing.contains(build.id) ? pending[build.id]?.mutationID : nil)
        copy.updatedAt = Date()
        copy.mutationID = UUID().uuidString
        pending[copy.id] = copy
        conflictingBuildIDs.remove(copy.id)
        persistOutbox()
        publishBuilds()
        retryPendingBuilds()
    }

    func deleteBuild(_ build: CustomBuild) {
        var removed = build
        removed.deleted = true
        saveBuild(removed)
    }

    func duplicateBuild(_ build: CustomBuild) {
        saveBuild(CustomBuild(name: String((build.name + " · copie").prefix(80)), championID: build.championID, itemIDs: build.itemIDs))
    }

    /// Explicit conflict resolution discards only this device's pending copy.
    func useServerBuild(id: String) {
        guard isCurrentSession else { return }
        pending[id] = nil
        conflictingBuildIDs.remove(id)
        errorMessage = nil
        persistOutbox()
        publishBuilds()
    }

    func retryPendingBuilds() {
        guard ConnectivityStore.shared.isOnline, isCurrentSession else { return }
        for (id, build) in pending where !syncing.contains(id) && !conflictingBuildIDs.contains(id) {
            syncing.insert(id)
            let ref = user.collection("builds").document(id)
            let expectedRevision = build.revision
            let mutationID = build.mutationID
            let predecessorMutationID = build.predecessorMutationID
            let payload: [String: Any] = ["name": build.name, "championID": build.championID, "itemIDs": build.itemIDs,
                "revision": expectedRevision, "mutationID": build.mutationID,
                "deleted": build.deleted, "updatedAt": FieldValue.serverTimestamp(),
                "createdAt": expectedRevision == 0 ? FieldValue.serverTimestamp() : Timestamp(date: build.createdAt)]
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let current = try transaction.getDocument(ref)
                    // A crash or sign-out can occur after commit but before the ACK
                    // reaches the local outbox. Retrying that same operation is success.
                    let actualRevision = current.data()?["revision"] as? Int ?? 0
                    let decision = BuildWritePolicy.resolve(expectedRevision: expectedRevision,
                        serverRevision: actualRevision, mutationID: mutationID,
                        serverMutationID: current.data()?["mutationID"] as? String,
                        predecessorMutationID: predecessorMutationID)
                    let nextRevision: Int
                    switch decision {
                    case .alreadyApplied(let revision): return revision
                    case .write(let revision): nextRevision = revision
                    case .conflict:
                        errorPointer?.pointee = NSError(domain: "LeagueDex.BuildConflict", code: 409)
                        return nil
                    }
                    var fields = payload
                    fields["revision"] = nextRevision
                    if let created = current.data()?["createdAt"] { fields["createdAt"] = created }
                    transaction.setData(fields, forDocument: ref)
                    return nextRevision
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.syncing.remove(id)
                    guard self.isCurrentSession else { return }
                    if let error {
                        if (error as NSError).domain == "LeagueDex.BuildConflict" {
                            self.conflictingBuildIDs.insert(id)
                            self.errorMessage = "Ce build a changé sur un autre appareil. Conservez une copie ou rechargez la version synchronisée."
                            self.publishBuilds()
                        } else {
                            self.errorMessage = "Build conservé sur cet appareil. La synchronisation sera réessayée."
                            self.scheduleRetry()
                        }
                    } else if let latest = self.pending[id] {
                        guard let committedRevision = result as? Int else {
                            self.errorMessage = "Confirmation incomplète. Le build local est conservé."
                            self.scheduleRetry()
                            return
                        }
                        if latest == build {
                            self.pending[id] = nil
                        } else {
                            var next = latest
                            next.revision = committedRevision
                            next.predecessorMutationID = nil
                            self.pending[id] = next
                        }
                        self.persistOutbox()
                        self.publishBuilds()
                        if self.pending.isEmpty && self.conflictingBuildIDs.isEmpty { self.errorMessage = nil }
                        self.retryPendingBuilds()
                    }
                }
            }
        }
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            self.retryPendingBuilds()
        }
    }

    private func persistOutbox() {
        if let bytes = try? JSONEncoder().encode(pending) { UserDefaults.standard.set(bytes, forKey: outboxKey) }
    }

    private func publishBuilds() {
        var merged = Dictionary(serverBuilds.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        pending.forEach { merged[$0.key] = $0.value }
        builds = merged.values.filter { !$0.deleted }.sorted { $0.updatedAt > $1.updatedAt }
        conflictedBuilds = pending.values.filter { conflictingBuildIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
        pendingBuildIDs = Set(pending.keys)
        hasPendingWrites = !pending.isEmpty || metadata.values.contains { $0.pending }
    }

    func saveComparison(leftID: String, rightID: String, level: Int) {
        guard isCurrentSession, leftID != rightID, (1...18).contains(level) else { return }
        let id = "\(leftID)_\(rightID)_\(level)"
        user.collection("comparisons").document(id).setData(["leftID": leftID, "rightID": rightID,
            "level": level, "updatedAt": FieldValue.serverTimestamp()]) { [weak self] error in
            Task { @MainActor [weak self] in if error != nil { self?.errorMessage = "Comparaison non enregistrée." } }
        }
    }

    func deleteComparison(_ comparison: SavedComparison) {
        guard isCurrentSession else { return }
        user.collection("comparisons").document(comparison.id).delete { [weak self] error in
            Task { @MainActor [weak self] in if error != nil { self?.errorMessage = "Suppression de comparaison refusée." } }
        }
    }

    /// Daily IDs are unique per uid/day; rules make all results immutable.
    func saveQuizRun(_ run: QuizRun) {
        guard isCurrentSession else { return }
        let id = run.dayKey.isEmpty ? run.id : "daily-\(run.dayKey)"
        user.collection("quizRuns").document(id).setData(["category": run.category, "difficulty": run.difficulty,
            "score": run.score, "correct": run.correct, "total": run.total,
            "completedAt": FieldValue.serverTimestamp(), "dayKey": run.dayKey]) { [weak self] error in
            Task { @MainActor [weak self] in
                if error != nil { self?.errorMessage = "Résultat non synchronisé ou défi déjà enregistré sur un autre appareil." }
            }
        }
    }
}
