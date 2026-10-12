import SwiftUI
import MapKit
import CoreLocation

private enum VenueKind: String, CaseIterable, Identifiable {
    case all = "Tous"
    case bars = "Bars e-sport"
    case lan = "Salles LAN"

    var id: Self { self }

    func includes(_ venue: DBVenue) -> Bool {
        switch self {
        case .all: return true
        case .bars: return venue.type.localizedCaseInsensitiveContains("Bar")
        case .lan: return venue.type.localizedCaseInsensitiveContains("LAN")
        }
    }
}

struct VenuesMapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6033, longitude: 1.8883),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )
    @State private var selectedVenueID: String?
    @State private var selectedKind: VenueKind = .all
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Conserve les lieux existants et leurs données d'itinéraire.
    private let venues = [
        DBVenue(id: "1", name: "Meltdown Paris", address: "6 Passage des Vernonnes, Paris",
                latitude: 48.866, longitude: 2.352, type: "Bar E-sport"),
        DBVenue(id: "2", name: "Esport Arena Lyon", address: "Place Bellecour, Lyon",
                latitude: 45.757, longitude: 4.832, type: "Salle LAN"),
        DBVenue(id: "3", name: "Meltdown Lille", address: "14 Rue Masséna, Lille",
                latitude: 50.637, longitude: 3.058, type: "Bar E-sport")
    ]

    private var visibleVenues: [DBVenue] {
        venues.filter { selectedKind.includes($0) }
    }

    private var selectedVenue: DBVenue? {
        visibleVenues.first { $0.id == selectedVenueID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        ForEach(VenueKind.allCases) { kind in
                            LeagueFilterChip(title: kind.rawValue, isSelected: selectedKind == kind) {
                                selectedKind = kind
                                if selectedVenue == nil { selectedVenueID = nil }
                            }
                        }
                    }
                    .padding(.horizontal, LeagueTheme.Space.md)
                    .padding(.vertical, LeagueTheme.Space.sm)
                }
                .background(LeagueTheme.surface)

                HStack(spacing: LeagueTheme.Space.sm) {
                    Text("\(visibleVenues.count) lieu(x)")
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                    Spacer()
                    Menu {
                        ForEach(visibleVenues) { venue in
                            Button(venue.name) { focus(on: venue) }
                        }
                    } label: {
                        Label("Choisir un lieu", systemImage: "list.bullet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LeagueTheme.gold)
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Affiche la liste des lieux disponibles sur la carte")
                    Button(action: recenterOnUser) {
                        Image(systemName: "location.fill")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(
                                locationManager.userLocation == nil
                                    ? LeagueTheme.muted : LeagueTheme.gold
                            )
                    }
                    .disabled(locationManager.userLocation == nil)
                    .accessibilityLabel("Recentrer sur ma position")
                }
                .padding(.horizontal, LeagueTheme.Space.md)
                .background(LeagueTheme.background)

                if locationManager.authorizationStatus == .denied
                    || locationManager.authorizationStatus == .restricted {
                    Text("Localisation désactivée : les lieux restent consultables, sans distance GPS.")
                        .font(.caption)
                        .foregroundStyle(LeagueTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LeagueTheme.Space.md)
                        .background(LeagueTheme.surface)
                }

                ZStack(alignment: .bottom) {
                    Map(position: $cameraPosition, selection: $selectedVenueID) {
                        UserAnnotation()
                        ForEach(visibleVenues) { venue in
                            Annotation(venue.name, coordinate: venue.coordinate) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 16))
                                    .padding(12)
                                    .background(LeagueTheme.gold, in: Circle())
                                    .foregroundStyle(LeagueTheme.background)
                                    .overlay {
                                        Circle().strokeBorder(LeagueTheme.text.opacity(0.7), lineWidth: 1)
                                    }
                                    .accessibilityLabel("\(venue.name), \(venue.type)")
                            }
                            .tag(venue.id)
                        }
                    }
                    .accessibilityLabel("Carte des lieux e-sport")

                    if let venue = selectedVenue {
                        venuePanel(venue)
                            .padding(.horizontal, LeagueTheme.Space.md)
                            .padding(.bottom, LeagueTheme.Space.sm)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: selectedVenueID)
            }
            .navigationTitle("Lieux E-sport")
            .onAppear { locationManager.requestLocation() }
        }
    }

    private func venuePanel(_ venue: DBVenue) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                    Text(venue.type)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LeagueTheme.cyan)
                    Text(venue.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(LeagueTheme.text)
                    Text(venue.address)
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: LeagueTheme.Space.xs)
                Button { selectedVenueID = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(LeagueTheme.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Fermer la fiche du lieu")
            }

            if let userLoc = locationManager.userLocation {
                let target = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
                let origin = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                let kilometers = origin.distance(from: target) / 1000

                Label(String(format: "À %.1f km de votre position", kilometers),
                      systemImage: "location")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LeagueTheme.text)
            }

            Button {
                // Itinéraire Apple Plans préservé.
                let address = "http://maps.apple.com/?daddr=\(venue.latitude),\(venue.longitude)"
                if let url = URL(string: address) { openURL(url) }
            } label: {
                Label("S'y rendre (Ouvrir Plans)", systemImage: "car.fill")
            }
            .buttonStyle(LeagueActionButtonStyle())
        }
        .padding(LeagueTheme.Space.md)
        .leagueSurface(radius: LeagueTheme.Corner.panel)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    }

    private func focus(on venue: DBVenue) {
        selectedVenueID = venue.id
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: venue.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
                )
            )
        }
    }

    private func recenterOnUser() {
        guard let user = locationManager.userLocation else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: user,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }
}
