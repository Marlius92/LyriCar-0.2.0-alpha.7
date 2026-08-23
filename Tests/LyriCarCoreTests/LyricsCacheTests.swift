import XCTest
@testable import LyriCarCore

final class LyricsCacheTests: XCTestCase {
    func testStoresAndExpiresHits() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LyriCarTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = try LyricsCache(directory: directory, hitTTL: 10, missTTL: 5)
        let track = TrackIdentity(id: "track", title: "Song", artists: ["Artist"], duration: 20)
        let document = LyricsDocument(
            provider: .local,
            trackTitle: "Song",
            artistName: "Artist",
            duration: 20,
            lines: [LyricLine(index: 0, timestamp: 1, text: "Line")]
        )
        let now = Date(timeIntervalSince1970: 1_000)
        try await cache.store(document, for: track, now: now)

        switch await cache.lookup(track, now: now.addingTimeInterval(5)) {
        case .hit(let cached): XCTAssertEqual(cached.lines.first?.text, "Line")
        default: XCTFail("Expected cache hit")
        }

        if case .absent = await cache.lookup(track, now: now.addingTimeInterval(11)) {
            // expected
        } else {
            XCTFail("Expected expired record")
        }
    }

    func testNegativeCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LyriCarTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try LyricsCache(directory: directory)
        let track = TrackIdentity(title: "Missing", artists: ["Artist"], duration: 20)
        try await cache.storeMiss(for: track)
        if case .cachedMiss = await cache.lookup(track) {
            // expected
        } else {
            XCTFail("Expected cached miss")
        }
    }
}
