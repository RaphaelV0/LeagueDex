import Foundation
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

struct VenueDraft {
    var name = ""
    var address = ""
    var type = "Bar E-sport"
    var openingHours = ""
    var phone = ""
    var website = ""
    var details = ""

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Firestore is the single catalog for public places. The SDK caches snapshots
/// offline; new submissions require a connected Firebase account.
@MainActor
final class VenueViewModel: ObservableObject {
    @Published private(set) var venues: [DBVenue] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isFromCache = true
    @Published private(set) var isSaving = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        listener = db.collection("venues")
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

    func addVenue(_ draft: VenueDraft, at coordinate: CLLocationCoordinate2D) async throws {
        guard Auth.auth().currentUser != nil else {
            throw VenueSubmissionError.notAuthenticated
        }
        guard ConnectivityStore.shared.isOnline else {
            throw VenueSubmissionError.offline
        }
        guard !isSaving else {
            throw VenueSubmissionError.alreadySaving
        }

        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let name = trimmed(draft.name)
        let address = trimmed(draft.address)
        guard !name.isEmpty, !address.isEmpty,
              name.count <= 120, address.count <= 250,
              draft.openingHours.count <= 500,
              draft.phone.count <= 60,
              draft.website.count <= 300,
              draft.details.count <= 1500,
              ["Bar E-sport", "Salle LAN", "Autre lieu gaming"].contains(draft.type),
              (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            throw VenueSubmissionError.invalidFields
        }
        guard !venues.contains(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame &&
            $0.address.compare(address, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw VenueSubmissionError.duplicate
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw VenueSubmissionError.notAuthenticated
        }
        isSaving = true
        defer { isSaving = false }

        // The authenticated UID and server timestamp are validated again by
        // firestore.rules. The existing public venues remain untouched.
        let data: [String: Any] = [
            "name": name,
            "address": address,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "type": draft.type,
            "openingHours": trimmed(draft.openingHours),
            "phone": trimmed(draft.phone),
            "website": trimmed(draft.website),
            "details": trimmed(draft.details),
            "authorUID": uid,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("venues").document().setData(data)
    }
}

enum VenueSubmissionError: LocalizedError {
    case notAuthenticated
    case offline
    case alreadySaving
    case invalidFields
    case duplicate
    case addressNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Connecte-toi à ton compte Firebase pour ajouter un lieu."
        case .offline: return "Une connexion Internet est nécessaire pour ajouter un lieu."
        case .alreadySaving: return "L'enregistrement est déjà en cours."
        case .invalidFields: return "Vérifie le nom, l'adresse et les autres informations."
        case .duplicate: return "Ce lieu existe déjà dans la carte."
        case .addressNotFound: return "Adresse introuvable dans Apple Plans. Essaie une adresse plus précise."
        }
    }
}
