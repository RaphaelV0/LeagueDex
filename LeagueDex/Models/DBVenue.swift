import Foundation
import CoreLocation
import FirebaseFirestore

struct DBVenue: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let type: String
    
    // Initialiseur personnalisé pour pouvoir créer facilement des objets en dur sans embêter Firestore
    init(id: String? = nil, name: String, address: String, latitude: Double, longitude: Double, type: String) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
