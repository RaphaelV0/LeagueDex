import Foundation
import Combine
import FirebaseFirestore

/// Read-only Firestore venue catalog. Firestore SDK caches viewed documents
/// automatically for offline use; there is no second local database.
@MainActor
final class VenueViewModel: ObservableObject {
    @Published private(set) var venues: [DBVenue] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isFromCache = true

    private var listener: ListenerRegistration?

    init() {
        listener = Firestore.firestore().collection("venues")
            .addSnapshotListener(includeMetadataChanges: true) { @Sendable [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = "Impossible de synchroniser les lieux : \(error.localizedDescription)"
                        return
                    }
                    guard let snapshot else { return }
                    self.venues = snapshot.documents.compactMap { try? $0.data(as: DBVenue.self) }
                        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                    self.isFromCache = snapshot.metadata.isFromCache
                    self.errorMessage = nil
                }
            }
    }

    deinit {
        listener?.remove()
    }
}
