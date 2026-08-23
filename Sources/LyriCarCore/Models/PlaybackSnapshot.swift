import Foundation

public struct PlaybackSnapshot: Codable, Hashable, Sendable {
    public var track: TrackIdentity
    public var position: TimeInterval
    public var isPlaying: Bool
    public var capturedAt: Date
    public var deviceID: String?

    public init(
        track: TrackIdentity,
        position: TimeInterval,
        isPlaying: Bool,
        capturedAt: Date = Date(),
        deviceID: String? = nil
    ) {
        self.track = track
        self.position = min(max(0, position), track.duration)
        self.isPlaying = isPlaying
        self.capturedAt = capturedAt
        self.deviceID = deviceID
    }

    public func estimatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return min(max(0, position), track.duration) }
        let elapsed = max(0, date.timeIntervalSince(capturedAt))
        return min(max(0, position + elapsed), track.duration)
    }
}
