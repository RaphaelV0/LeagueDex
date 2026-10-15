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
    @Published private(set) var proposals: [VenueProposal] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    let uid: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var proposalListener: ListenerRegistration?

    /// One proposal per account per UTC day. Firestore rules verify this ID using
    /// server time, so changing the device clock does not bypass the quota.
    static func submissionKey(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

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

    init(uid: String) {
        self.uid = uid
        listener = db.collection("venues").addSnapshotListener { @Sendable [weak self] snapshot, error in
            Task { @MainActor [weak self] in
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
        proposalListener = db.collection("users").document(uid).collection("venueProposals")
            .addSnapshotListener { @Sendable [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = "Historique des propositions indisponible : \(error.localizedDescription)"
                        return
                    }
                    self.proposals = (snapshot?.documents ?? []).compactMap { doc in
                        let fields = doc.data()
                        guard let name = fields["name"] as? String,
                              let address = fields["address"] as? String,
                              let status = fields["status"] as? String else { return nil }
                        return VenueProposal(id: doc.documentID, name: name, address: address, status: status,
                            createdAt: (fields["createdAt"] as? Timestamp)?.dateValue())
                    }.sorted { $0.id > $1.id }
                }
            }
    }

    deinit {
        listener?.remove()
        proposalListener?.remove()
    }

    func addVenue(_ draft: VenueDraft, at coordinate: CLLocationCoordinate2D) async throws {
        guard draft.canSubmit,
              (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else {
            throw VenueSubmissionError.invalidLocation
        }
        guard !isSaving else { throw VenueSubmissionError.alreadySaving }

        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAddress = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.count <= 120, normalizedAddress.count <= 250,
              draft.openingHours.count <= 500, draft.phone.count <= 60,
              draft.website.count <= 300, draft.details.count <= 1500 else {
            throw VenueSubmissionError.textTooLong
        }
        if venues.contains(where: {
            $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                && $0.address.compare(normalizedAddress, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            throw VenueSubmissionError.duplicateLocation
        }

        isSaving = true
        defer { isSaving = false }

        func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

        // All user submissions require review. Only admins can write to the
        // public venues catalog. Never optimistically display proposals as venues.
        let key = Self.submissionKey()
        var data: [String: Any] = [
            "authorUID": uid,
            "name": trimmed(draft.name),
            "address": trimmed(draft.address),
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "type": draft.type,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
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
        // createDocument via transaction does not overwrite a previously accepted
        // daily submission; offline duplicate attempts remain server protected.
        let ref = db.collection("users").document(uid).collection("venueProposals").document(key)
        let fields = data
        try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let previous = try transaction.getDocument(ref)
                guard !previous.exists else {
                    errorPointer?.pointee = VenueSubmissionError.dailyLimit as NSError
                    return nil
                }
                transaction.setData(fields, forDocument: ref)
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func reportVenue(_ venue: DBVenue, reason: String) async throws {
        guard let venueID = venue.id, !venueID.isEmpty else {
            throw VenueSubmissionError.invalidLocation
        }
        let validReasons = ["Adresse incorrecte", "Établissement fermé", "Informations erronées", "Autre"]
        guard validReasons.contains(reason) else { throw VenueSubmissionError.invalidLocation }
        let key = "\(venueID)_\(Self.submissionKey())"
        let ref = db.collection("users").document(uid).collection("venueReports").document(key)
        try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                guard try !transaction.getDocument(ref).exists else {
                    errorPointer?.pointee = VenueSubmissionError.alreadyReported as NSError
                    return nil
                }
                transaction.setData([
                    "authorUID": self.uid,
                    "venueID": venueID,
                    "reason": reason,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}

struct VenueProposal: Identifiable {
    let id: String
    let name: String
    let address: String
    let status: String
    let createdAt: Date?

    var statusLabel: String {
        switch status {
        case "approved": return "Accepté"
        case "rejected": return "Refusé"
        default: return "En attente de modération"
        }
    }
}

enum VenueSubmissionError: LocalizedError {
    case invalidLocation
    case alreadySaving
    case addressNotFound
    case duplicateLocation
    case textTooLong
    case dailyLimit
    case alreadyReported

    var errorDescription: String? {
        switch self {
        case .invalidLocation: return "Indiquez un nom et une adresse valides."
        case .alreadySaving: return "Un enregistrement est déjà en cours."
        case .addressNotFound: return "Adresse introuvable. Ajoutez la ville et le pays, puis réessayez."
        case .duplicateLocation: return "Ce lieu existe déjà à cette adresse. Vérifiez la liste."
        case .textTooLong: return "Certains champs sont trop longs. Raccourcissez les informations."
        case .dailyLimit: return "Tu as déjà proposé un lieu aujourd’hui. Réessaie demain (UTC)."
        case .alreadyReported: return "Ce lieu a déjà été signalé aujourd’hui."
        }
    }
}
