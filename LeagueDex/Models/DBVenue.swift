import Foundation
import CoreLocation
import FirebaseFirestore

/// Firestore's "venues" collection. Optional metadata keeps existing documents readable.
struct DBVenue: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let type: String

    let openingHours: String?
    let phone: String?
    let website: String?
    let details: String?

    init(
        id: String? = nil,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        type: String,
        openingHours: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.openingHours = openingHours
        self.phone = phone
        self.website = website
        self.details = details
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
