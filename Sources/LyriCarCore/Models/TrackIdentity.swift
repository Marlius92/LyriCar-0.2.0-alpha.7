import Foundation

public struct TrackIdentity: Codable, Hashable, Sendable {
    public var id: String?
    public var title: String
    public var artists: [String]
    public var album: String?
    public var duration: TimeInterval
    public var artworkURL: URL?

    public init(
        id: String? = nil,
        title: String,
        artists: [String],
        album: String? = nil,
        duration: TimeInterval,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.album = album
        self.duration = max(0, duration)
        self.artworkURL = artworkURL
    }

    public var primaryArtist: String {
        artists.first ?? ""
    }

    public var displayArtist: String {
        artists.joined(separator: ", ")
    }

    public var stableCacheKey: String {
        if let id, !id.isEmpty { return "spotify:\(id)" }
        return [title, displayArtist, album ?? "", String(Int(duration.rounded()))]
            .joined(separator: "|")
            .lowercased()
    }
}
