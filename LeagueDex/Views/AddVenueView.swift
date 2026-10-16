import SwiftUI
import MapKit

/// A single small form: enter a place, verify its address using Apple Maps,
/// and publish it to the shared Firestore map under the signed-in account.
struct AddVenueView: View {
    @ObservedObject var viewModel: VenueViewModel
    var onAdded: (CLLocationCoordinate2D) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var draft = VenueDraft()
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var verifiedAddress: String?
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lieu e-sport") {
                    TextField("Nom de l'établissement", text: $draft.name)
                        .textContentType(.organizationName)

                    Picker("Type de lieu", selection: $draft.type) {
                        Text("Bar e-sport").tag("Bar E-sport")
                        Text("Salle LAN").tag("Salle LAN")
                        Text("Autre lieu gaming").tag("Autre lieu gaming")
                    }

                    TextField("Adresse complète et ville", text: $draft.address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .onChange(of: draft.address) { _, _ in
                            coordinate = nil
                            verifiedAddress = nil
                            errorMessage = nil
                        }

                    Button {
                        Task { await verifyAddress() }
                    } label: {
                        HStack {
                            Label("Vérifier l'adresse", systemImage: "magnifyingglass")
                            Spacer()
                            if isSearching { ProgressView() }
                        }
                    }
                    .disabled(isSearching || draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let coordinate {
                    Section("Position à confirmer") {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                        ))) {
                            Marker(draft.name.isEmpty ? "Nouveau lieu" : draft.name, coordinate: coordinate)
                        }
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets())

                        if let verifiedAddress {
                            Label(verifiedAddress, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                        }
                        Text("Vérifie le repère sur la carte avant l'enregistrement.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Informations facultatives") {
                    TextField("Horaires d'ouverture", text: $draft.openingHours)
                    TextField("Téléphone", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("Site web", text: $draft.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Informations pratiques", text: $draft.details, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Text("Le lieu sera enregistré dans Firebase et apparaîtra sur la carte pour les utilisateurs connectés. L'ajout nécessite Internet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(LeagueTheme.danger)
                    }
                }

                Section {
                    Button {
                        Task { await saveVenue() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                                Text("Enregistrement…")
                            } else {
                                Label("Ajouter sur la carte", systemImage: "plus.circle.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!draft.canSubmit || coordinate == nil || isSearching || viewModel.isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LeagueTheme.background)
            .navigationTitle("Ajouter un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .tint(LeagueTheme.gold)
    }

    @MainActor
    private func verifyAddress() async {
        guard !isSearching else { return }
        let searched = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searched.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        coordinate = nil
        verifiedAddress = nil
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searched
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let result = try await MKLocalSearch(request: request).start()
            guard draft.address.trimmingCharacters(in: .whitespacesAndNewlines) == searched else { return }
            guard let match = result.mapItems.first else {
                throw VenueSubmissionError.addressNotFound
            }
            coordinate = match.placemark.coordinate
            verifiedAddress = match.placemark.title ?? searched
        } catch {
            errorMessage = "Adresse non vérifiée : \(error.localizedDescription)"
        }
    }

    @MainActor
    private func saveVenue() async {
        guard let coordinate, !viewModel.isSaving else { return }
        errorMessage = nil
        do {
            try await viewModel.addVenue(draft, at: coordinate)
            onAdded(coordinate)
            dismiss()
        } catch {
            errorMessage = "Impossible d'ajouter ce lieu : \(error.localizedDescription)"
        }
    }
}
