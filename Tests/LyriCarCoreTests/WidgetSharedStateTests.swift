import XCTest
@testable import LyriCarCore

final class WidgetSharedStateTests: XCTestCase {
    func testWidgetStateRoundTripsAndInterpolatesPlayback() throws {
        let captured = Date(timeIntervalSince1970: 1_000)
        let state = LyriCarWidgetSharedState(
            title: "Song",
            artist: "Artist",
            previous2: "-2",
            previous1: "-1",
            current: "current",
            next1: "+1",
            next2: "+2",
            position: 42,
            duration: 180,
            isPlaying: true,
            capturedAt: captured,
            currentLineStartedAt: 40,
            nextLineStartsAt: 46,
            karaokeEligible: true
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LyriCarWidgetSharedState.self, from: data)
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.estimatedPosition(at: captured.addingTimeInterval(3)), 45, accuracy: 0.001)
    }
}
