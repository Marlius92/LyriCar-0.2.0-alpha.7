import Foundation

/// Snapshot shared between the iPhone app and the WidgetKit extension.
/// The widget intentionally receives only presentation data; Spotify credentials
/// and the complete lyrics document never leave the app container.
public struct LyriCarWidgetSharedState: Codable, Hashable, Sendable {
    public var title: String
    public var artist: String
    public var previous2: String
    public var previous1: String
    public var current: String
    public var next1: String
    public var next2: String
    public var position: TimeInterval
    public var duration: TimeInterval
    public var isPlaying: Bool
    public var capturedAt: Date
    public var currentLineStartedAt: TimeInterval?
    public var nextLineStartsAt: TimeInterval?
    public var karaokeEligible: Bool

    public init(
        title: String,
        artist: String,
        previous2: String,
        previous1: String,
        current: String,
        next1: String,
        next2: String,
        position: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        capturedAt: Date,
        currentLineStartedAt: TimeInterval?,
        nextLineStartsAt: TimeInterval?,
        karaokeEligible: Bool
    ) {
        self.title = title
        self.artist = artist
        self.previous2 = previous2
        self.previous1 = previous1
        self.current = current
        self.next1 = next1
        self.next2 = next2
        self.position = max(0, position)
        self.duration = max(0, duration)
        self.isPlaying = isPlaying
        self.capturedAt = capturedAt
        self.currentLineStartedAt = currentLineStartedAt
        self.nextLineStartsAt = nextLineStartsAt
        self.karaokeEligible = karaokeEligible
    }

    public func estimatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return min(max(position, 0), duration) }
        return min(max(position + max(0, date.timeIntervalSince(capturedAt)), 0), duration)
    }

    public var playbackInterval: ClosedRange<Date> {
        let safeDuration = max(duration, 0.001)
        let safePosition = min(max(position, 0), safeDuration)
        let start = capturedAt.addingTimeInterval(-safePosition)
        return start...start.addingTimeInterval(safeDuration)
    }

    public var remainingInterval: ClosedRange<Date> {
        let estimated = estimatedPosition()
        let now = Date()
        return now...now.addingTimeInterval(max(0.001, duration - estimated))
    }

    public static let placeholder = LyriCarWidgetSharedState(
        title: "LyriCar",
        artist: "Apri LyriCar e avvia Spotify",
        previous2: "",
        previous1: "",
        current: "Testi sincronizzati",
        next1: "in attesa del brano…",
        next2: "",
        position: 0,
        duration: 1,
        isPlaying: false,
        capturedAt: Date(),
        currentLineStartedAt: nil,
        nextLineStartsAt: nil,
        karaokeEligible: false
    )
}

public enum LyriCarWidgetSharedStore {
    public static let stateKey = "lyricar.widget.shared-state.v1"

    /// This App Group is one of the groups authorized by the Signulous
    /// Distribution provisioning profile currently used for device testing.
    /// It can be replaced with an Apple Developer App Group later without
    /// touching the widget architecture.
    public static let appGroupIdentifier = "group.a4799f2e729d57e0.1"

    public static func save(_ state: LyriCarWidgetSharedState) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    public static func load() -> LyriCarWidgetSharedState? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(LyriCarWidgetSharedState.self, from: data)
    }

    public static func clear() {
        UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: stateKey)
    }
}
