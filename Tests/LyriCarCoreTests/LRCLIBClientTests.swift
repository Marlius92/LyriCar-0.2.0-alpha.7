import XCTest
@testable import LyriCarCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct StubHTTPClient: HTTPClient {
    let response: HTTPResponse
    func send(_ request: URLRequest) async throws -> HTTPResponse { response }
}

final class LRCLIBClientTests: XCTestCase {
    func testDecodesExactSyncedLyrics() async throws {
        let payload = """
        {
          "id": 42,
          "name": "Test Song",
          "trackName": "Test Song",
          "artistName": "Test Artist",
          "albumName": "Test Album",
          "duration": 120.0,
          "instrumental": false,
          "plainLyrics": "First\\nSecond",
          "syncedLyrics": "[00:01.00]First\\n[00:05.00]Second"
        }
        """.data(using: .utf8)!
        let client = LRCLIBClient(
            httpClient: StubHTTPClient(response: HTTPResponse(data: payload, statusCode: 200)),
            maximumAttempts: 1
        )
        let track = TrackIdentity(title: "Test Song", artists: ["Test Artist"], album: "Test Album", duration: 120)
        let document = try await client.lyrics(for: track)
        XCTAssertEqual(document?.providerID, 42)
        XCTAssertEqual(document?.lines.count, 2)
        XCTAssertEqual(document?.lines[1].text, "Second")
    }

    func testReturnsNilOnNotFoundThenEmptySearch() async throws {
        struct SequencedClient: HTTPClient {
            let state: State
            actor State {
                var count = 0
                func next() -> HTTPResponse {
                    defer { count += 1 }
                    return count == 0
                        ? HTTPResponse(data: Data(), statusCode: 404)
                        : HTTPResponse(data: Data("[]".utf8), statusCode: 200)
                }
            }
            func send(_ request: URLRequest) async throws -> HTTPResponse { await state.next() }
        }

        let client = LRCLIBClient(httpClient: SequencedClient(state: .init()), maximumAttempts: 1)
        let track = TrackIdentity(title: "Missing", artists: ["Nobody"], duration: 10)
        let result = try await client.lyrics(for: track)
        XCTAssertNil(result)
    }
}
