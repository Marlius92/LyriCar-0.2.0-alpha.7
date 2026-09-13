import AVFAudio
import UIKit

/// Best-effort CarPlay detection for the standard, non-entitled LyriCar target.
/// A true CarPlay scene is authoritative when available; otherwise we fall back
/// to the system Car Audio route. This works for both wired and wireless CarPlay
/// without requiring a CarPlay app entitlement.
@MainActor
enum CarPlayConnectionDetector {
    static func isConnected() -> Bool {
        hasCarPlayScene || hasCarAudioRoute
    }

    private static var hasCarAudioRoute: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return (route.outputs + route.inputs).contains { $0.portType == .carAudio }
    }

    private static var hasCarPlayScene: Bool {
        UIApplication.shared.connectedScenes.contains { scene in
            let role = scene.session.role.rawValue.lowercased()
            return role.contains("car") || role.contains("templateapplication")
        }
    }
}
