import SwiftUI
import MapKit
import CoreLocation

/// Shown when the user taps a pin or chooses a venue from the list.
struct VenueDetailView: View {
    let venue: DBVenue
    let userCoordinate: CLLocationCoordinate2D?

    @Environment(\.dismiss) private var dismiss

    private var routeURL: URL? {
        URL(string: "https://maps.apple.com/?daddr=\(venue.latitude),\(venue.longitude)&dirflg=d")
    }

    private var websiteURL: URL? {
        guard let site = venue.website?.trimmingCharacters(in: .whitespacesAndNewlines),
              !site.isEmpty else { return nil }
        let normalized = site.contains("://") ? site : "https://\(site)"
        guard let url = URL(string: normalized),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { return nil }
        return url
    }

    private var phoneURL: URL? {
        guard let phone = venue.phone else { return nil }
        let dialable = phone.filter { $0.isNumber || $0 == "+" }
        guard !dialable.isEmpty else { return nil }
        return URL(string: "tel:\(dialable)")
    }

    private var distanceText: String? {
        guard let userCoordinate else { return nil }
        let current = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let destination = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
        return String(format: "%.1f km de votre position", current.distance(from: destination) / 1000)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                        Text(venue.type)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LeagueTheme.cyan)

                        Text(venue.name)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(LeagueTheme.text)
                            .fixedSize(horizontal: false, vertical: true)

                        Label(venue.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(LeagueTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if let distanceText {
                            Label(distanceText, systemImage: "location")
                                .font(.subheadline)
                                .foregroundStyle(LeagueTheme.gold)
                        }
                    }

                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: venue.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                        )
                    )) {
                        Marker(venue.name, coordinate: venue.coordinate)
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.large))
                    .accessibilityLabel("Position du lieu sur la carte")

                    if let routeURL {
                        Link(destination: routeURL) {
                            Label("Itinéraire avec Apple Plans", systemImage: "car.fill")
                        }
                        .buttonStyle(LeagueActionButtonStyle())
                        .accessibilityHint("Ouvre Apple Plans pour calculer l'itinéraire")
                    }

                    VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                        LeagueSectionHeader(title: "Horaires")
                        Text(venue.openingHours.flatMap { $0.isEmpty ? nil : $0 } ?? "Horaires non renseignés")
                            .font(.body)
                            .foregroundStyle(LeagueTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Informations déclaratives, à confirmer directement auprès de l'établissement.")
                            .font(.caption)
                            .foregroundStyle(LeagueTheme.muted)
                    }
                    .padding(LeagueTheme.Space.md)
                    .leagueSurface()

                    if let details = venue.details, !details.isEmpty {
                        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                            LeagueSectionHeader(title: "Informations pratiques")
                            Text(details)
                                .font(.body)
                                .foregroundStyle(LeagueTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(LeagueTheme.Space.md)
                        .leagueSurface()
                    }

                    if venue.phone?.isEmpty == false || venue.website?.isEmpty == false {
                        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                            LeagueSectionHeader(title: "Contact")
                            if let phone = venue.phone, !phone.isEmpty, let phoneURL {
                                Link(destination: phoneURL) {
                                    Label(phone, systemImage: "phone.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(minHeight: 44)
                                }
                            } else if let phone = venue.phone, !phone.isEmpty {
                                Text(phone)
                            }
                            if let websiteURL {
                                Link(destination: websiteURL) {
                                    Label("Consulter le site web", systemImage: "safari")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        .foregroundStyle(LeagueTheme.gold)
                        .padding(LeagueTheme.Space.md)
                        .leagueSurface()
                    }
                }
                .padding(LeagueTheme.Space.md)
                .padding(.bottom, LeagueTheme.Space.xl)
            }
            .background(LeagueTheme.background)
            .navigationTitle("Détails du lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .tint(LeagueTheme.gold)
    }
}
