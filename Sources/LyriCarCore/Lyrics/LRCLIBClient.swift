import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LRCLIBError: Error, Equatable {
    case invalidURL
    case invalidResponse(Int)
    case rateLimited
    case malformedPayload
}

public struct LRCLIBClient: LyricsProvider, Sendable {
    private let httpClient: any HTTPClient
    private let parser: LRCParser
    private let baseURL: URL
    private let clientHeader: String
    private let maximumAttempts: Int

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        parser: LRCParser = LRCParser(),
        baseURL: URL = URL(string: "https://lrclib.net")!,
        clientHeader: String = "LyriCar/0.1 (personal iOS client)",
        maximumAttempts: Int = 3
    ) {
        self.httpClient = httpClient
        self.parser = parser
        self.baseURL = baseURL
        self.clientHeader = clientHeader
        self.maximumAttempts = max(1, maximumAttempts)
    }

    public func lyrics(for track: TrackIdentity) async throws -> LyricsDocument? {
        if let exact = try await exactLookup(track), let document = try makeDocument(from: exact) {
            return document
        }

        let candidates = try await search(track)
            .filter { $0.syncedLyrics?.isEmpty == false || $0.instrumental == true }
            .sorted { score($0, for: track) > score($1, for: track) }

        for candidate in candidates.prefix(8) {
            if let document = try makeDocument(from: candidate) {
                return document
            }
        }
        return nil
    }

    private func exactLookup(_ track: TrackIdentity) async throws -> LRCLIBPayload? {
        var items = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.primaryArtist),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        if let album = track.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        let response = try await request(path: "/api/get", queryItems: items)
        if response.statusCode == 404 { return nil }
        guard (200..<300).contains(response.statusCode) else {
            throw LRCLIBError.invalidResponse(response.statusCode)
        }
        return try JSONDecoder().decode(LRCLIBPayload.self, from: response.data)
    }

    private func search(_ track: TrackIdentity) async throws -> [LRCLIBPayload] {
        var items = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.primaryArtist)
        ]
        if let album = track.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        let response = try await request(path: "/api/search", queryItems: items)
        guard (200..<300).contains(response.statusCode) else {
            throw LRCLIBError.invalidResponse(response.statusCode)
        }
        return try JSONDecoder().decode([LRCLIBPayload].self, from: response.data)
    }

    private func request(path: String, queryItems: [URLQueryItem]) async throws -> HTTPResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw LRCLIBError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LRCLIBError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientHeader, forHTTPHeaderField: "Lrclib-Client")

        var lastResponse: HTTPResponse?
        for attempt in 0..<maximumAttempts {
            let response = try await httpClient.send(request)
            lastResponse = response
            if response.statusCode != 429 && !(500...599).contains(response.statusCode) {
                return response
            }
            if attempt + 1 < maximumAttempts {
                let delay = UInt64(pow(2, Double(attempt)) * 350_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }

        guard let lastResponse else { throw LRCLIBError.malformedPayload }
        if lastResponse.statusCode == 429 { throw LRCLIBError.rateLimited }
        return lastResponse
    }

    private func makeDocument(from payload: LRCLIBPayload) throws -> LyricsDocument? {
        if payload.instrumental == true {
            return LyricsDocument(
                provider: .lrclib,
                providerID: payload.id,
                trackTitle: payload.trackName ?? payload.name ?? "",
                artistName: payload.artistName ?? "",
                albumName: payload.albumName,
                duration: payload.duration ?? 0,
                lines: [],
                plainLyrics: payload.plainLyrics,
                instrumental: true
            )
        }

        guard let synced = payload.syncedLyrics, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let parsed = try parser.parse(synced)
        return LyricsDocument(
            provider: .lrclib,
            providerID: payload.id,
            trackTitle: payload.trackName ?? payload.name ?? "",
            artistName: payload.artistName ?? "",
            albumName: payload.albumName,
            duration: payload.duration ?? parsed.lines.last?.timestamp ?? 0,
            lines: parsed.lines,
            plainLyrics: payload.plainLyrics,
            instrumental: false
        )
    }

    private func score(_ candidate: LRCLIBPayload, for track: TrackIdentity) -> Double {
        let title = TextNormalization.similarity(candidate.trackName ?? candidate.name ?? "", track.title)
        let artist = TextNormalization.similarity(candidate.artistName ?? "", track.primaryArtist)
        let album: Double
        if let requestedAlbum = track.album, !requestedAlbum.isEmpty {
            album = TextNormalization.similarity(candidate.albumName ?? "", requestedAlbum)
        } else {
            album = 0.5
        }

        let durationScore: Double
        if let duration = candidate.duration, track.duration > 0 {
            let difference = abs(duration - track.duration)
            durationScore = max(0, 1 - difference / 12)
        } else {
            durationScore = 0.5
        }

        let syncedBonus = candidate.syncedLyrics?.isEmpty == false ? 0.08 : 0
        return title * 0.48 + artist * 0.30 + album * 0.08 + durationScore * 0.14 + syncedBonus
    }
}

private struct LRCLIBPayload: Codable, Sendable {
    var id: Int?
    var name: String?
    var trackName: String?
    var artistName: String?
    var albumName: String?
    var duration: TimeInterval?
    var instrumental: Bool?
    var plainLyrics: String?
    var syncedLyrics: String?
}
