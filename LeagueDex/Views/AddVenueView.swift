import SwiftUI
import MapKit

/// Collect a venue, resolve its address through Apple Maps, then publish it
/// as a private, moderated Firestore proposal after confirming the address.
struct AddVenueView: View {
    @ObservedObject var viewModel: VenueViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = VenueDraft()
    @State private var matchedCoordinate: CLLocationCoordinate2D?
    @State private var matchedAddress: String?
    @State private var resolving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Le lieu") {
                    TextField("Nom de l'établissement", text: $draft.name)
                        .textContentType(.organizationName)

                    Picker("Catégorie", selection: $draft.type) {
                        Text("Bar e-sport").tag("Bar E-sport")
                        Text("Salle LAN").tag("Salle LAN")
                        Text("Autre lieu gaming").tag("Autre lieu gaming")
                    }

                    TextField("Adresse complète, ville et pays", text: $draft.address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .onChange(of: draft.address) { _ in
                            matchedCoordinate = nil
                            matchedAddress = nil
                            errorMessage = nil
                        }

                    Button {
                        Task { await resolveAddress() }
                    } label: {
                        HStack {
                            Label("Vérifier l'adresse sur Plans", systemImage: "magnifyingglass")
                            Spacer()
                            if resolving { ProgressView() }
                        }
                    }
                    .disabled(resolving || draft.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let coordinate = matchedCoordinate {
                    Section("Position trouvée — à confirmer") {
                        Map(initialPosition: .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                            )
                        )) {
                            Marker(draft.name.isEmpty ? "Nouveau lieu" : draft.name,
                                   coordinate: coordinate)
                        }
                        .frame(height: 175)
                        .listRowInsets(EdgeInsets())
                        if let matchedAddress {
                            Label(matchedAddress, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                        }
                        Text("Vérifiez que le repère correspond bien au lieu avant de le publier.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Horaires et informations") {
                    TextField("Horaires (ex. lun–sam 14h–23h)", text: $draft.openingHours, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Téléphone (facultatif)", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("Site web (https://...)", text: $draft.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Infos pratiques : jeux, événements, accès…",
                              text: $draft.details, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Text("Ta proposition sera enregistrée dans ton compte Firebase et examinée avant d’être visible sur la carte. Une proposition par jour UTC est autorisée. Les horaires et informations doivent être exacts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LeagueTheme.danger)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await publish() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                                Text("Envoi…")
                            } else {
                                Label("Soumettre à la modération", systemImage: "paperplane.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!draft.canSubmit || matchedCoordinate == nil || viewModel.isSaving || resolving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LeagueTheme.background)
            .navigationTitle("Proposer un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .tint(LeagueTheme.gold)
        }
    }

    @MainActor
    private func resolveAddress() async {
        guard !resolving else { return }
        resolving = true
        errorMessage = nil
        defer { resolving = false }

        let searched = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searched
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let result = try await MKLocalSearch(request: request).start()
            guard searched == draft.address.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            guard let mapItem = result.mapItems.first else {
                throw VenueSubmissionError.addressNotFound
            }
            matchedCoordinate = mapItem.placemark.coordinate
            matchedAddress = mapItem.placemark.title ?? searched
        } catch {
            matchedCoordinate = nil
            matchedAddress = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish() async {
        guard let matchedCoordinate, draft.canSubmit else { return }
        errorMessage = nil

        do {
            try await viewModel.addVenue(draft, at: matchedCoordinate)
            dismiss()
        } catch {
            errorMessage = "Proposition non enregistrée : \(error.localizedDescription). Vérifie la connexion et la limite quotidienne."
        }
    }
}
