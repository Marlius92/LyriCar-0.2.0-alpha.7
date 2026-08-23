import Foundation

public protocol LyricsProvider: Sendable {
    func lyrics(for track: TrackIdentity) async throws -> LyricsDocument?
}
