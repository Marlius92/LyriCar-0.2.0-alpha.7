import XCTest
@testable import LyriCarCore

final class PlaybackAndFormattingTests: XCTestCase {
    func testSnapshotInterpolatesOnlyWhilePlaying() {
        let captured = Date(timeIntervalSince1970: 100)
        let track = TrackIdentity(title: "Song", artists: ["Artist"], duration: 100)
        let playing = PlaybackSnapshot(track: track, position: 10, isPlaying: true, capturedAt: captured)
        let paused = PlaybackSnapshot(track: track, position: 10, isPlaying: false, capturedAt: captured)
        XCTAssertEqual(playing.estimatedPosition(at: captured.addingTimeInterval(3)), 13, accuracy: 0.001)
        XCTAssertEqual(paused.estimatedPosition(at: captured.addingTimeInterval(3)), 10, accuracy: 0.001)
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatting.clock(62.9), "1:02")
        XCTAssertEqual(DurationFormatting.clock(3_661), "1:01:01")
        XCTAssertEqual(DurationFormatting.remaining(position: 60, duration: 180), "-2:00")
    }

    func testDriftDetectsSeek() {
        let track = TrackIdentity(id: "abc", title: "Song", artists: ["Artist"], duration: 300)
        let previous = PlaybackSnapshot(track: track, position: 10, isPlaying: true, capturedAt: Date(timeIntervalSince1970: 10))
        let natural = PlaybackSnapshot(track: track, position: 12, isPlaying: true, capturedAt: Date(timeIntervalSince1970: 12))
        let seek = PlaybackSnapshot(track: track, position: 50, isPlaying: true, capturedAt: Date(timeIntervalSince1970: 12))
        XCTAssertFalse(PlaybackDrift().isSeek(previous: previous, incoming: natural))
        XCTAssertTrue(PlaybackDrift().isSeek(previous: previous, incoming: seek))
    }

    func testPlaybackClockFiltersQuantizedBacksteps() {
        let track = TrackIdentity(id: "clock", title: "Song", artists: ["Artist"], duration: 300)
        let start = Date(timeIntervalSince1970: 1_000)
        var clock = PlaybackClock()

        _ = clock.apply(
            PlaybackSnapshot(track: track, position: 10, isPlaying: true, capturedAt: start),
            at: start
        )
        let secondDate = start.addingTimeInterval(0.9)
        let second = clock.apply(
            PlaybackSnapshot(track: track, position: 10, isPlaying: true, capturedAt: secondDate),
            at: secondDate
        )

        XCTAssertNotNil(second)
        XCTAssertGreaterThanOrEqual(second?.position ?? 0, 10.89)
        XCTAssertGreaterThanOrEqual(
            second?.estimatedPosition(at: start.addingTimeInterval(1.2)) ?? 0,
            11.19
        )
    }

    func testPlaybackClockStillAppliesRealSeek() {
        let track = TrackIdentity(id: "clock", title: "Song", artists: ["Artist"], duration: 300)
        let start = Date(timeIntervalSince1970: 1_000)
        var clock = PlaybackClock()
        _ = clock.apply(
            PlaybackSnapshot(track: track, position: 50, isPlaying: true, capturedAt: start),
            at: start
        )
        let seekDate = start.addingTimeInterval(1)
        let sought = clock.apply(
            PlaybackSnapshot(track: track, position: 12, isPlaying: true, capturedAt: seekDate),
            at: seekDate
        )
        XCTAssertEqual(sought?.position ?? -1, 12, accuracy: 0.001)
    }

    func testPlaybackClockFreezesAtContinuousPositionWhenPausing() {
        let track = TrackIdentity(id: "clock", title: "Song", artists: ["Artist"], duration: 300)
        let start = Date(timeIntervalSince1970: 1_000)
        var clock = PlaybackClock()
        _ = clock.apply(
            PlaybackSnapshot(track: track, position: 20, isPlaying: true, capturedAt: start),
            at: start
        )
        let pauseDate = start.addingTimeInterval(0.9)
        let paused = clock.apply(
            PlaybackSnapshot(track: track, position: 20, isPlaying: false, capturedAt: pauseDate),
            at: pauseDate
        )
        XCTAssertFalse(paused?.isPlaying ?? true)
        XCTAssertGreaterThanOrEqual(paused?.position ?? 0, 20.89)
        XCTAssertEqual(
            paused?.estimatedPosition(at: start.addingTimeInterval(5)) ?? -1,
            paused?.position ?? -2,
            accuracy: 0.001
        )
    }
}
