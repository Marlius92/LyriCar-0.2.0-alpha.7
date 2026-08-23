import Foundation

/// Reconciles coarse or delayed player snapshots with a continuous local clock.
///
/// Media APIs are usually polled much less frequently than the renderer refreshes.
/// Replacing the interpolated position with every raw response can therefore make
/// the progress bar and timed lyrics jump backwards. `PlaybackClock` filters those
/// small stale samples while preserving real seeks, track changes and play/pause.
public struct PlaybackClock: Sendable {
    public var seekThreshold: TimeInterval
    public var pausedSeekThreshold: TimeInterval
    public var maximumForwardNudge: TimeInterval
    public var forwardNudgeRatio: Double
    public var staleEventTolerance: TimeInterval

    public private(set) var output: PlaybackSnapshot?
    private var source: PlaybackSnapshot?

    public init(
        seekThreshold: TimeInterval = 1.75,
        pausedSeekThreshold: TimeInterval = 0.15,
        maximumForwardNudge: TimeInterval = 0.20,
        forwardNudgeRatio: Double = 0.35,
        staleEventTolerance: TimeInterval = 0.05
    ) {
        self.seekThreshold = max(0.25, seekThreshold)
        self.pausedSeekThreshold = max(0.01, pausedSeekThreshold)
        self.maximumForwardNudge = max(0, maximumForwardNudge)
        self.forwardNudgeRatio = min(max(forwardNudgeRatio, 0), 1)
        self.staleEventTolerance = max(0, staleEventTolerance)
    }

    public mutating func reset() {
        source = nil
        output = nil
    }

    @discardableResult
    public mutating func apply(
        _ incoming: PlaybackSnapshot?,
        at date: Date = Date()
    ) -> PlaybackSnapshot? {
        guard let incoming else {
            reset()
            return nil
        }

        guard
            let previousSource = source,
            let previousOutput = output,
            previousSource.track.stableCacheKey == incoming.track.stableCacheKey
        else {
            return anchor(
                source: incoming,
                position: incoming.estimatedPosition(at: date),
                at: date
            )
        }

        if incoming.capturedAt.timeIntervalSince(previousSource.capturedAt) < -staleEventTolerance {
            return previousOutput
        }

        let sourceElapsed = max(0, incoming.capturedAt.timeIntervalSince(previousSource.capturedAt))
        let rawDelta = incoming.position - previousSource.position
        let expectedForward = previousSource.isPlaying ? sourceElapsed : 0

        let backwardSeek = rawDelta < -seekThreshold
        let forwardSeek = rawDelta > expectedForward + seekThreshold
        let pausedSeek = !previousSource.isPlaying
            && !incoming.isPlaying
            && abs(rawDelta) >= pausedSeekThreshold
        let isSeek = backwardSeek || forwardSeek || pausedSeek

        let displayedNow = previousOutput.estimatedPosition(at: date)
        let sourceNow = incoming.estimatedPosition(at: date)
        let outputPosition: TimeInterval

        if isSeek {
            outputPosition = sourceNow
        } else if incoming.isPlaying {
            let positiveError = sourceNow - displayedNow
            if positiveError > 0 {
                let correction = min(maximumForwardNudge, positiveError * forwardNudgeRatio)
                outputPosition = displayedNow + correction
            } else {
                outputPosition = displayedNow
            }
        } else if previousOutput.isPlaying {
            outputPosition = max(displayedNow, sourceNow)
        } else {
            outputPosition = pausedSeek ? sourceNow : displayedNow
        }

        return anchor(source: incoming, position: outputPosition, at: date)
    }

    private mutating func anchor(
        source incoming: PlaybackSnapshot,
        position: TimeInterval,
        at date: Date
    ) -> PlaybackSnapshot {
        let anchored = PlaybackSnapshot(
            track: incoming.track,
            position: position,
            isPlaying: incoming.isPlaying,
            capturedAt: date,
            deviceID: incoming.deviceID
        )
        source = incoming
        output = anchored
        return anchored
    }
}
