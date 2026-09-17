import SwiftUI
import MapKit
import CoreLocation

struct VenuesMapView: View {
    @StateObject private var locationManager = LocationManager()
    
    // Position de la caméra de la carte
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6033, longitude: 1.8883),
            span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)
        )
    )
    
    // ID du lieu actuellement sélectionné sur la carte
    @State private var selectedVenueID: String?
    @Environment(\.openURL) var openURL
    
    let venues = [
        DBVenue(id: "1", name: "Meltdown Paris", address: "6 Passage des Vernonnes, Paris", latitude: 48.866, longitude: 2.352, type: "Bar E-sport"),
        DBVenue(id: "2", name: "Esport Arena Lyon", address: "Place Bellecour, Lyon", latitude: 45.757, longitude: 4.832, type: "Salle LAN"),
        DBVenue(id: "3", name: "Meltdown Lille", address: "14 Rue Masséna, Lille", latitude: 50.637, longitude: 3.058, type: "Bar E-sport")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // CARTE INTERACTIVE AVEC SÉLECTION
                Map(position: $cameraPosition, selection: $selectedVenueID) {
                    // Affiche le point bleu de l'utilisateur
                    UserAnnotation()
                    
                    // Affiche les épingles des lieux
                    ForEach(venues) { venue in
                        Annotation(venue.name, coordinate: venue.coordinate) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 16))
                                .padding(10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .tag(venue.id) // <--- Le tag se place ici en tant que modificateur
                    }
                }
                
                // PANNEAU DE DÉTAIL / ITINÉRAIRE (S'affiche au clic sur un lieu)
                if let selectedID = selectedVenueID,
                   let venue = venues.first(where: { $0.id == selectedID }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(venue.type).font(.caption).bold().foregroundColor(.blue)
                                Text(venue.name).font(.title3).bold()
                                Text(venue.address).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                selectedVenueID = nil // Fermer le panneau
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Calcul dynamique de la distance par rapport à l'utilisateur
                        if let userLoc = locationManager.userLocation {
                            let venueLoc = CLLocation(latitude: venue.latitude, longitude: venue.longitude)
                            let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                            let distanceInKm = userCLLoc.distance(from: venueLoc) / 1000.0
                            
                            Text(String(format: "📍 À %.1f km de votre position", distanceInKm))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.primary)
                        }
                        
                        // BOUTON POUR LANCER LE GPS (APPLE PLANS)
                        Button(action: {
                            let urlString = "http://maps.apple.com/?daddr=\(venue.latitude),\(venue.longitude)"
                            if let url = URL(string: urlString) {
                                openURL(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "car.fill")
                                Text("S'y rendre (Ouvrir Plans)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .bold()
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .cornerRadius(24)
                    .shadow(radius: 10)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: selectedVenueID)
                }
            }
            .navigationTitle("Lieux E-sport")
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
}
