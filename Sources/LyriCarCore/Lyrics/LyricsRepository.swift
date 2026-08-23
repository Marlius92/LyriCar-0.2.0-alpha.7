import Foundation

public actor LyricsRepository {
    private let provider: any LyricsProvider
    private let cache: LyricsCache

    public init(provider: any LyricsProvider, cache: LyricsCache) {
        self.provider = provider
        self.cache = cache
    }

    public func lyrics(for track: TrackIdentity, forceRefresh: Bool = false) async throws -> LyricsDocument? {
        if !forceRefresh {
            switch await cache.lookup(track) {
            case .hit(let document):
                return document
            case .cachedMiss:
                return nil
            case .absent:
                break
            }
        }

        if let document = try await provider.lyrics(for: track) {
            try? await cache.store(document, for: track)
            return document
        }
        try? await cache.storeMiss(for: track)
        return nil
    }

    public func clearCache() async throws {
        try await cache.clear()
    }
}
