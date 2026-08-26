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

    /// Core Location delivers callbacks on the run loop used to create the
    /// manager. The manager is created on MainActor, but the Objective-C
    /// delegate requirement is imported as nonisolated. Assert that dynamic
    /// guarantee before touching published UI state.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        // Intentionally empty: LyriCar never reads or stores the user's position.
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Transient Core Location failures do not stop Spotify interpolation.
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            beginUpdates()
        } else if status == .denied || status == .restricted {
            stop()
        }
    }

    private func beginUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        isRunning = true
    }
}
