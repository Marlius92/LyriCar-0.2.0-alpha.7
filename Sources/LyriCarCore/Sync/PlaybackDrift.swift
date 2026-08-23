import Foundation

public struct PlaybackDrift: Sendable {
    public var seekThreshold: TimeInterval

    public init(seekThreshold: TimeInterval = 1.75) {
        self.seekThreshold = max(0.2, seekThreshold)
    }

    public func isSeek(previous: PlaybackSnapshot, incoming: PlaybackSnapshot) -> Bool {
        guard previous.track.id == incoming.track.id || previous.track.stableCacheKey == incoming.track.stableCacheKey else {
            return true
        }
        let expected = previous.estimatedPosition(at: incoming.capturedAt)
        return abs(expected - incoming.position) >= seekThreshold
    }
}
