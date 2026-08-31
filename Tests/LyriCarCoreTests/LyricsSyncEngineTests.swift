import XCTest
@testable import LyriCarCore

final class LyricsSyncEngineTests: XCTestCase {
    private let document = LyricsDocument(
        provider: .local,
        trackTitle: "Test",
        artistName: "LyriCar",
        duration: 30,
        lines: [
            LyricLine(index: 0, timestamp: 2, text: "zero"),
            LyricLine(index: 1, timestamp: 6, text: "one"),
            LyricLine(index: 2, timestamp: 10, text: "two"),
            LyricLine(index: 3, timestamp: 14, text: "three"),
            LyricLine(index: 4, timestamp: 18, text: "four")
        ]
    )

    func testBuildsFiveLineWindow() {
        let frame = LyricsSyncEngine().frame(for: document, playbackPosition: 10.5)
        XCTAssertEqual(frame.current?.text, "two")
        XCTAssertEqual(frame.previous2?.text, "zero")
        XCTAssertEqual(frame.previous1?.text, "one")
        XCTAssertEqual(frame.next1?.text, "three")
        XCTAssertEqual(frame.next2?.text, "four")
    }

    func testPositiveOffsetDelaysLyrics() {
        let frame = LyricsSyncEngine().frame(for: document, playbackPosition: 10.5, userOffset: 1)
        XCTAssertEqual(frame.current?.text, "one")
    }

    func testBeforeFirstLineShowsUpcomingLines() {
        let frame = LyricsSyncEngine().frame(for: document, playbackPosition: 0.5)
        XCTAssertNil(frame.current)
        XCTAssertEqual(frame.next1?.text, "zero")
        XCTAssertEqual(frame.next2?.text, "one")
    }

    func testTransitionProgressRisesNearNextLine() {
        let engine = LyricsSyncEngine(transitionWindow: 0.5)
        let early = engine.frame(for: document, playbackPosition: 9.0)
        let late = engine.frame(for: document, playbackPosition: 9.8)
        XCTAssertEqual(early.transitionProgress, 0, accuracy: 0.001)
        XCTAssertGreaterThan(late.transitionProgress, 0.5)
    }
}

extension LyricsSyncEngineTests {
    func testKaraokeIsEnabledOnlyWithFollowingTimestamp() {
        let middle = LyricsSyncEngine().frame(for: document, playbackPosition: 10.5)
        XCTAssertTrue(middle.karaokeEligible)
        XCTAssertGreaterThan(middle.lineProgress, 0)

        let last = LyricsSyncEngine().frame(for: document, playbackPosition: 19.0)
        XCTAssertFalse(last.karaokeEligible)
    }
}
