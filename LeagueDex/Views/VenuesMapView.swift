import SwiftUI
import MapKit
import CoreLocation

/// A simple, read-only map of the e-sport venues stored in Firestore.
struct VenuesMapView: View {
    @StateObject private var viewModel = VenueViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var selectedVenue: DBVenue?
    @State private var showingAddVenue = false
    @State private var focusWhenLocated = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6033, longitude: 1.8883),
            span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
        )
    )

    private var visibleVenues: [DBVenue] {
        viewModel.venues.filter { venue in
            searchText.isEmpty || venue.name.localizedStandardContains(searchText)
                || venue.address.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(LeagueTheme.danger)
                        .padding(LeagueTheme.Space.md)
                } else if visibleVenues.isEmpty {
                    Text("Aucun lieu disponible dans Firebase ou dans le cache.")
                        .font(.footnote)
                        .foregroundStyle(LeagueTheme.muted)
                        .padding(LeagueTheme.Space.md)
                }

                Map(position: $cameraPosition) {
                    UserAnnotation()
                    ForEach(visibleVenues) { venue in
                        Annotation(venue.name, coordinate: venue.coordinate) {
                            Button {
                                selectedVenue = venue
                            } label: {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(LeagueTheme.background)
                                    .frame(width: 44, height: 44)
                                    .background(LeagueTheme.gold, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Afficher \(venue.name)")
                        }
                    }
                }
                .accessibilityLabel("Carte des lieux e-sport")

                Text("\(visibleVenues.count) lieux affichés")
                    .font(.caption)
                    .foregroundStyle(LeagueTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LeagueTheme.Space.md)
            }
            .background(LeagueTheme.background)
            .navigationTitle("Lieux e-sport")
            .searchable(text: $searchText, prompt: "Rechercher un lieu ou une ville")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddVenue = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Ajouter un lieu sur la carte")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let coordinate = locationManager.userLocation {
                            focus(on: coordinate)
                        } else {
                            focusWhenLocated = true
                            locationManager.requestLocation()
                        }
                    } label: {
                        Image(systemName: "location.fill")
                    }
                    .accessibilityLabel("Me localiser")
                }
            }
            .sheet(item: $selectedVenue) { venue in
                VenueDetailView(venue: venue, userCoordinate: locationManager.userLocation)
            }
            .sheet(isPresented: $showingAddVenue) {
                AddVenueView(viewModel: viewModel) { coordinate in
                    searchText = ""
                    focus(on: coordinate)
                }
            }
            .onChange(of: locationManager.userLocation?.latitude) { _, _ in
                guard focusWhenLocated, let coordinate = locationManager.userLocation else { return }
                focusWhenLocated = false
                focus(on: coordinate)
            }
        }
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        ))
    }
}
