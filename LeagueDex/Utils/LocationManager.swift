import Foundation
import CoreLocation
import Combine

/// One-shot map positioning instead of a continuous high-accuracy GPS session.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published private(set) var userLocation: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isLocating = false
    @Published private(set) var locationError: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        locationError = nil

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLocating = true
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            locationError = "Autorisez la localisation dans Réglages pour afficher votre distance."
        @unknown default:
            isLocating = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        case .denied, .restricted:
            isLocating = false
            locationError = "Localisation désactivée : la carte reste consultable."
        case .notDetermined:
            break
        @unknown default:
            isLocating = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        isLocating = false
        locationError = nil
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        // The map still works when a location fix cannot be obtained.
        if (error as? CLError)?.code != .locationUnknown {
            locationError = "Position indisponible. Réessayez depuis la carte."
        }
    }

}
