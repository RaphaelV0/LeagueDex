import SwiftUI
import MapKit
import CoreLocation

private enum VenueKind: String, CaseIterable, Identifiable {
    case all = "Tous"
    case bars = "Bars e-sport"
    case lan = "Salles LAN"
    case other = "Autres"

    var id: Self { self }

    func includes(_ venue: DBVenue) -> Bool {
        let isBar = venue.type.localizedCaseInsensitiveContains("bar")
        let isLAN = venue.type.localizedCaseInsensitiveContains("LAN")
        switch self {
        case .all: return true
        case .bars: return isBar
        case .lan: return isLAN
        case .other: return !isBar && !isLAN
        }
    }
}

struct VenuesMapView: View {
    @StateObject private var viewModel = VenueViewModel()
    @StateObject private var locationManager = LocationManager()

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6033, longitude: 1.8883),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )
    @State private var selectedKind: VenueKind = .all
    @State private var selectedVenue: DBVenue?
    @State private var addingVenue = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleVenues: [DBVenue] {
        viewModel.venues.filter { selectedKind.includes($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        ForEach(VenueKind.allCases) { kind in
                            LeagueFilterChip(title: kind.rawValue,
                                             isSelected: selectedKind == kind) {
                                selectedKind = kind
                            }
                        }
                    }
                    .padding(.horizontal, LeagueTheme.Space.md)
                    .padding(.vertical, LeagueTheme.Space.sm)
                }
                .background(LeagueTheme.surface)

                HStack(spacing: LeagueTheme.Space.sm) {
                    Text("\(visibleVenues.count) lieux")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LeagueTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)

                    Menu {
                        ForEach(visibleVenues) { venue in
                            Button(venue.name) { focus(on: venue) }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(LeagueTheme.gold)
                    }
                    .accessibilityLabel("Choisir un lieu dans la liste")

                    Button(action: focusOnUser) {
                        Image(systemName: "location.fill")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(LeagueTheme.gold)
                    }
                    .accessibilityLabel("Recentrer ou actualiser ma position")

                    Button { addingVenue = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .frame(width: 44, height: 44)
                            .font(.title3)
                            .foregroundStyle(LeagueTheme.gold)
                    }
                    .accessibilityLabel("Ajouter un lieu sur la carte")
                }
                .padding(.horizontal, LeagueTheme.Space.md)
                .background(LeagueTheme.background)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(LeagueTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LeagueTheme.Space.md)
                        .background(LeagueTheme.surface)
                }

                if let warning = locationManager.locationError {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(LeagueTheme.muted)
                        Spacer(minLength: 0)
                        if locationManager.authorizationStatus != .denied
                            && locationManager.authorizationStatus != .restricted {
                            Button("Réessayer") { locationManager.requestLocation() }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LeagueTheme.gold)
                        }
                    }
                    .padding(LeagueTheme.Space.md)
                    .background(LeagueTheme.surface)
                }

                ZStack(alignment: .topTrailing) {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        ForEach(visibleVenues) { venue in
                            Annotation(venue.name, coordinate: venue.coordinate) {
                                Button {
                                    selectedVenue = venue
                                } label: {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(LeagueTheme.background)
                                        .frame(width: 46, height: 46)
                                        .background(LeagueTheme.gold, in: Circle())
                                        .overlay {
                                            Circle()
                                                .strokeBorder(LeagueTheme.text.opacity(0.65), lineWidth: 1)
                                        }
                                        .shadow(color: .black.opacity(0.2), radius: 5)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Détails de \(venue.name), \(venue.type)")
                            }
                        }
                    }
                    .accessibilityLabel("Carte interactive des lieux e-sport")

                    if locationManager.isLocating {
                        ProgressView()
                            .tint(LeagueTheme.gold)
                            .padding(LeagueTheme.Space.md)
                            .background(LeagueTheme.surface, in: Circle())
                            .padding(LeagueTheme.Space.md)
                            .accessibilityLabel("Localisation en cours")
                    }
                }
            }
            .background(LeagueTheme.background)
            .navigationTitle("Lieux e-sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingVenue = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Proposer un nouveau lieu")
                }
            }
            .sheet(item: $selectedVenue) { venue in
                VenueDetailView(venue: venue, userCoordinate: locationManager.userLocation)
            }
            .sheet(isPresented: $addingVenue) {
                AddVenueView(viewModel: viewModel)
            }
            .onAppear { locationManager.requestLocation() }
        }
    }

    private func focus(on venue: DBVenue) {
        withAnimation(reduceMotion ? nil : LeagueMotion.standard) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: venue.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.07)
                )
            )
        }
        selectedVenue = venue
    }

    private func focusOnUser() {
        guard let coordinate = locationManager.userLocation else {
            locationManager.requestLocation()
            return
        }
        withAnimation(reduceMotion ? nil : LeagueMotion.standard) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }
}
