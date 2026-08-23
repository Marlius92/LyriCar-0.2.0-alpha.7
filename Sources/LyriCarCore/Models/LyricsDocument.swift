import Foundation

public enum LyricsProviderKind: String, Codable, Hashable, Sendable {
    case lrclib
    case local
    case unknown
}

public struct LyricsDocument: Codable, Hashable, Sendable {
    public var provider: LyricsProviderKind
    public var providerID: Int?
    public var trackTitle: String
    public var artistName: String
    public var albumName: String?
    public var duration: TimeInterval
    public var lines: [LyricLine]
    public var plainLyrics: String?
    public var instrumental: Bool
    public var fetchedAt: Date

    public init(
        provider: LyricsProviderKind,
        providerID: Int? = nil,
        trackTitle: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval,
        lines: [LyricLine],
        plainLyrics: String? = nil,
        instrumental: Bool = false,
        fetchedAt: Date = Date()
    ) {
        self.provider = provider
        self.providerID = providerID
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumName = albumName
        self.duration = max(0, duration)
        self.lines = lines.sorted { $0.timestamp < $1.timestamp }
        self.plainLyrics = plainLyrics
        self.instrumental = instrumental
        self.fetchedAt = fetchedAt
    }
}
