import Foundation
import Combine
import CoreLocation
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Shared public venue catalog. New user submissions are written to Firestore's
/// "venues" collection and become available through the live snapshot listener.
@MainActor
final class VenueViewModel: ObservableObject {
    @Published private(set) var remoteVenues: [DBVenue] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Preserve the three locations already shipped with LeagueDex. Firestore entries
    // with the same name take precedence over bundled data.
    private let featured: [DBVenue] = [
        DBVenue(id: "featured-paris", name: "Meltdown Paris",
                address: "6 Passage des Vernonnes, Paris", latitude: 48.866,
                longitude: 2.352, type: "Bar E-sport"),
        DBVenue(id: "featured-lyon", name: "Esport Arena Lyon",
                address: "Place Bellecour, Lyon", latitude: 45.757,
                longitude: 4.832, type: "Salle LAN"),
        DBVenue(id: "featured-lille", name: "Meltdown Lille",
                address: "14 Rue Masséna, Lille", latitude: 50.637,
                longitude: 3.058, type: "Bar E-sport")
    ]

    var venues: [DBVenue] {
        let bundled = featured.filter { original in
            !remoteVenues.contains {
                $0.name.compare(original.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
        return (remoteVenues + bundled).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    init() {
        listener = db.collection("venues").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.errorMessage = "Impossible de synchroniser les lieux : \(error.localizedDescription)"
                return
            }
            guard let snapshot else { return }
            self.remoteVenues = snapshot.documents.compactMap {
                try? $0.data(as: DBVenue.self)
            }
            self.errorMessage = nil
        }
    }

    deinit {
        listener?.remove()
    }

    func addVenue(_ draft: VenueDraft, at coordinate: CLLocationCoordinate2D) async throws {
        guard draft.canSubmit,
              (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            throw VenueSubmissionError.invalidLocation
        }
        guard !isSaving else { throw VenueSubmissionError.alreadySaving }
        isSaving = true
        defer { isSaving = false }

        func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

        var data: [String: Any] = [
            "name": trimmed(draft.name),
            "address": trimmed(draft.address),
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "type": draft.type
        ]
        for (key, value) in [
            ("openingHours", draft.openingHours),
            ("phone", draft.phone),
            ("website", draft.website),
            ("details", draft.details)
        ] {
            let clean = trimmed(value)
            if !clean.isEmpty { data[key] = clean }
        }
        // Create a document with a unique Firestore ID; no local-only fake success.
        try await db.collection("venues").document().setData(data)
    }
}

enum VenueSubmissionError: LocalizedError {
    case invalidLocation
    case alreadySaving
    case addressNotFound

    var errorDescription: String? {
        switch self {
        case .invalidLocation: return "Indiquez un nom et une adresse valides."
        case .alreadySaving: return "Un enregistrement est déjà en cours."
        case .addressNotFound: return "Adresse introuvable. Ajoutez la ville et le pays, puis réessayez."
        }
    }
}
