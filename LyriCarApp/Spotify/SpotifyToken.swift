import Foundation

struct SpotifyToken: Codable, Hashable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scope: String?
    var tokenType: String

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 90
    }
}

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let scope: String?
    let expiresIn: TimeInterval
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }

    func token(preservingRefreshToken previous: String? = nil) -> SpotifyToken {
        SpotifyToken(
            accessToken: accessToken,
            refreshToken: refreshToken ?? previous,
            expiresAt: Date().addingTimeInterval(expiresIn),
            scope: scope,
            tokenType: tokenType
        )
    }
}
