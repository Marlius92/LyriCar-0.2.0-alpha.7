import Combine
import CoreLocation
import Foundation

/// Optional, privacy-preserving background keep-alive used only while driving.
/// Location samples are deliberately discarded and never persisted or transmitted.
@MainActor
final class DriveModeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 1_000
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            beginUpdates()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            beginUpdates()
        case .denied, .restricted:
            isRunning = false
        @unknown default:
            isRunning = false
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        isRunning = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            beginUpdates()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Intentionally empty: LyriCar never reads or stores the user's position.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient Core Location failures do not stop Spotify interpolation.
    }

    private func beginUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        isRunning = true
    }
}
