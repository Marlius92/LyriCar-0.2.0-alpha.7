import Foundation
import LyriCarCore

@MainActor
final class SpotifyWebAPI {
    private let auth: SpotifyAuthController
    private let decoder = JSONDecoder()

    init(auth: SpotifyAuthController) {
        self.auth = auth
    }

    func currentPlayback() async throws -> PlaybackSnapshot? {
        let result = try await request(path: "/v1/me/player", method: "GET")
        if result.statusCode == 204 { return nil }
        guard (200..<300).contains(result.statusCode) else {
            throw SpotifyAPIError.http(result.statusCode, result.bodyString)
        }
        let payload = try decoder.decode(CurrentPlaybackResponse.self, from: result.data)
        guard let item = payload.item,
              item.type == nil || item.type == "track",
              let name = item.name,
              let durationMS = item.durationMS else { return nil }
        let duration = TimeInterval(durationMS) / 1000
        let track = TrackIdentity(
            id: item.id,
            title: name,
            artists: (item.artists ?? []).map(\.name),
            album: item.album?.name,
            duration: duration,
            artworkURL: (item.album?.images ?? [])
                .sorted(by: { ($0.width ?? 0) > ($1.width ?? 0) })
                .compactMap(\.url)
                .first
        )
        return PlaybackSnapshot(
            track: track,
            position: TimeInterval(payload.progressMS ?? 0) / 1000,
            isPlaying: payload.isPlaying,
            capturedAt: Date(),
            deviceID: payload.device?.id
        )
    }

    func play(deviceID: String? = nil) async throws {
        try await command(path: "/v1/me/player/play", method: "PUT", deviceID: deviceID)
    }

    func pause(deviceID: String? = nil) async throws {
        try await command(path: "/v1/me/player/pause", method: "PUT", deviceID: deviceID)
    }

    func next(deviceID: String? = nil) async throws {
        try await command(path: "/v1/me/player/next", method: "POST", deviceID: deviceID)
    }

    func previous(deviceID: String? = nil) async throws {
        try await command(path: "/v1/me/player/previous", method: "POST", deviceID: deviceID)
    }

    private func command(path: String, method: String, deviceID: String?) async throws {
        var resolvedPath = path
        if let deviceID, !deviceID.isEmpty {
            var components = URLComponents()
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
            if let query = components.percentEncodedQuery { resolvedPath += "?\(query)" }
        }
        let result = try await request(path: resolvedPath, method: method)
        guard (200..<300).contains(result.statusCode) else {
            throw SpotifyAPIError.http(result.statusCode, result.bodyString)
        }
    }

    private func request(
        path: String,
        method: String,
        retriedAuthentication: Bool = false,
        retriedRateLimit: Bool = false,
        retriedServerError: Bool = false
    ) async throws -> SpotifyHTTPResult {
        let token = try await auth.validToken()
        guard let url = URL(string: "https://api.spotify.com\(path)") else {
            throw SpotifyAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAPIError.invalidResponse }
        let result = SpotifyHTTPResult(
            statusCode: http.statusCode,
            data: data,
            retryAfter: Self.retryAfter(from: http)
        )

        if http.statusCode == 401, !retriedAuthentication {
            _ = try await auth.validToken(forceRefresh: true)
            return try await self.request(
                path: path,
                method: method,
                retriedAuthentication: true,
                retriedRateLimit: retriedRateLimit,
                retriedServerError: retriedServerError
            )
        }

        if http.statusCode == 429, !retriedRateLimit {
            let delay = min(max(result.retryAfter ?? 1, 0.5), 10)
            try await Task.sleep(for: .seconds(delay))
            return try await self.request(
                path: path,
                method: method,
                retriedAuthentication: retriedAuthentication,
                retriedRateLimit: true,
                retriedServerError: retriedServerError
            )
        }

        if (500...599).contains(http.statusCode), !retriedServerError {
            try await Task.sleep(for: .milliseconds(750))
            return try await self.request(
                path: path,
                method: method,
                retriedAuthentication: retriedAuthentication,
                retriedRateLimit: retriedRateLimit,
                retriedServerError: true
            )
        }

        return result
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(value) { return seconds }
        return nil
    }
}

private struct SpotifyHTTPResult {
    let statusCode: Int
    let data: Data
    let retryAfter: TimeInterval?
    var bodyString: String { String(data: data, encoding: .utf8) ?? "" }
}

private struct CurrentPlaybackResponse: Decodable {
    let isPlaying: Bool
    let progressMS: Int?
    let item: SpotifyTrack?
    let device: SpotifyDevice?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case progressMS = "progress_ms"
        case item
        case device
    }
}

private struct SpotifyTrack: Decodable {
    let id: String?
    let name: String?
    let durationMS: Int?
    let artists: [SpotifyArtist]?
    let album: SpotifyAlbum?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, type
        case durationMS = "duration_ms"
    }
}

private struct SpotifyArtist: Decodable { let name: String }
private struct SpotifyDevice: Decodable { let id: String? }
private struct SpotifyAlbum: Decodable {
    let name: String?
    let images: [SpotifyImage]?
}
private struct SpotifyImage: Decodable {
    let url: URL?
    let width: Int?
}

enum SpotifyAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL Spotify non valido."
        case .invalidResponse:
            return "Risposta Spotify non valida."
        case .http(let status, let body):
            if status == 401 { return "Sessione Spotify scaduta. Ricollega l'account." }
            if status == 403 {
                return "Spotify ha rifiutato il comando. Verifica Premium, allowlist e dispositivo attivo."
            }
            if status == 404 { return "Nessun dispositivo Spotify attivo trovato." }
            if status == 429 { return "Limite temporaneo Spotify raggiunto. Riprova tra poco." }
            let conciseBody = body.isEmpty ? "nessun dettaglio" : String(body.prefix(280))
            return "Errore Spotify HTTP \(status): \(conciseBody)"
        }
    }
}
