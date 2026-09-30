#if canImport(ActivityKit)
import ActivityKit
import Foundation

public struct LyriCarActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var artist: String
        public var previous2: String
        public var previousLine: String
        public var currentLine: String
        public var nextLine: String
        public var next2: String
        public var position: TimeInterval
        public var duration: TimeInterval
        public var isPlaying: Bool
        public var capturedAt: Date

        public init(
            title: String,
            artist: String,
            previous2: String,
            previousLine: String,
            currentLine: String,
            nextLine: String,
            next2: String,
            position: TimeInterval,
            duration: TimeInterval,
            isPlaying: Bool,
            capturedAt: Date
        ) {
            self.title = title
            self.artist = artist
            self.previous2 = previous2
            self.previousLine = previousLine
            self.currentLine = currentLine
            self.nextLine = nextLine
            self.next2 = next2
            self.position = position
            self.duration = duration
            self.isPlaying = isPlaying
            self.capturedAt = capturedAt
        }

        public func estimatedPosition(at date: Date = Date()) -> TimeInterval {
            guard isPlaying else { return min(max(position, 0), duration) }
            return min(max(position + max(0, date.timeIntervalSince(capturedAt)), 0), duration)
        }

        public var clampedProgress: Double {
            guard duration > 0 else { return 0 }
            return min(max(estimatedPosition() / duration, 0), 1)
        }

        public var playbackInterval: ClosedRange<Date> {
            let safeDuration = max(duration, 0.001)
            let start = capturedAt.addingTimeInterval(-min(max(position, 0), safeDuration))
            return start...start.addingTimeInterval(safeDuration)
        }
    }

    public var sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }
}
#endif
