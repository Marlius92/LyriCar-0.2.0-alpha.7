import AVFAudio

/// Best-effort CarPlay detection for the standard, non-entitled LyriCar target.
/// CarPlay exposes the active car-audio route for both wired and wireless
/// connections, so this can work without a CarPlay application entitlement.
@MainActor
enum CarPlayConnectionDetector {
    static func isConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return (route.outputs + route.inputs).contains { $0.portType == .carAudio }
    }
}
