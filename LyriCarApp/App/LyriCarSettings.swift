import Combine
import Foundation

@MainActor
final class LyriCarSettings: ObservableObject {
    private enum Key {
        static let lyricsOffset = "lyricsOffset"
        static let fontScale = "fontScale"
        static let fadeStrength = "fadeStrength"
        static let transitionWindow = "transitionWindow"
        static let driveMode = "driveMode"
        static let liveActivity = "liveActivity"
    }

    @Published var lyricsOffset: TimeInterval { didSet { defaults.set(lyricsOffset, forKey: Key.lyricsOffset) } }
    @Published var fontScale: Double { didSet { defaults.set(fontScale, forKey: Key.fontScale) } }
    @Published var fadeStrength: Double { didSet { defaults.set(fadeStrength, forKey: Key.fadeStrength) } }
    @Published var transitionWindow: TimeInterval { didSet { defaults.set(transitionWindow, forKey: Key.transitionWindow) } }
    @Published var driveModeEnabled: Bool { didSet { defaults.set(driveModeEnabled, forKey: Key.driveMode) } }
    @Published var liveActivityEnabled: Bool { didSet { defaults.set(liveActivityEnabled, forKey: Key.liveActivity) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lyricsOffset = defaults.object(forKey: Key.lyricsOffset) as? Double ?? 0
        fontScale = defaults.object(forKey: Key.fontScale) as? Double ?? 1
        fadeStrength = defaults.object(forKey: Key.fadeStrength) as? Double ?? 1
        transitionWindow = defaults.object(forKey: Key.transitionWindow) as? Double ?? 0.55
        driveModeEnabled = defaults.object(forKey: Key.driveMode) as? Bool ?? false
        liveActivityEnabled = defaults.object(forKey: Key.liveActivity) as? Bool ?? true
    }

    func resetVisuals() {
        lyricsOffset = 0
        fontScale = 1
        fadeStrength = 1
        transitionWindow = 0.55
    }
}
