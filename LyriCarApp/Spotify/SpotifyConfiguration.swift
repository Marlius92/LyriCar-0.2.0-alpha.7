import Combine
import Foundation

enum SpotifyConfigurationError: LocalizedError {
    case missingClientID
    case invalidClientID
    case invalidRedirectURL

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Client ID Spotify non configurato. Incollalo nella schermata iniziale di LyriCar."
        case .invalidClientID:
            return "Client ID Spotify non valido. Copia soltanto il valore Client ID dal dashboard Spotify."
        case .invalidRedirectURL:
            return "Redirect URI Spotify non valido."
        }
    }
}

struct SpotifyConfiguration: Sendable, Equatable {
    static let defaultRedirectURI = "lyricar-login://callback"
    static let defaultScopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "user-modify-playback-state"
    ]

    let clientID: String
    let redirectURI: String
    let scopes: [String]

    init(
        clientID: String,
        redirectURI: String = SpotifyConfiguration.defaultRedirectURI,
        scopes: [String] = SpotifyConfiguration.defaultScopes
    ) {
        self.clientID = Self.normalizedClientID(clientID)
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    static var bundled: SpotifyConfiguration {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
        let redirectURI = Bundle.main.object(forInfoDictionaryKey: "SpotifyRedirectURI") as? String
            ?? defaultRedirectURI
        return SpotifyConfiguration(clientID: clientID, redirectURI: redirectURI)
    }

    var isConfigured: Bool {
        let value = Self.normalizedClientID(clientID)
        return !value.isEmpty
            && !value.localizedCaseInsensitiveContains("YOUR_SPOTIFY_CLIENT_ID")
            && !value.contains(where: { $0.isWhitespace })
    }

    func validate() throws {
        guard isConfigured else { throw SpotifyConfigurationError.missingClientID }
        guard clientID.count >= 16, clientID.count <= 128 else {
            throw SpotifyConfigurationError.invalidClientID
        }
        guard let url = URL(string: redirectURI), url.scheme != nil else {
            throw SpotifyConfigurationError.invalidRedirectURL
        }
    }

    static func normalizedClientID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class SpotifyConfigurationStore: ObservableObject {
    private enum Key {
        static let clientID = "spotify.clientID"
    }

    @Published private(set) var clientID: String

    private let defaults: UserDefaults
    private let bundledConfiguration: SpotifyConfiguration

    init(
        defaults: UserDefaults = .standard,
        bundledConfiguration: SpotifyConfiguration = .bundled
    ) {
        self.defaults = defaults
        self.bundledConfiguration = bundledConfiguration

        let saved = SpotifyConfiguration.normalizedClientID(
            defaults.string(forKey: Key.clientID) ?? ""
        )
        if !saved.isEmpty {
            clientID = saved
        } else if bundledConfiguration.isConfigured {
            clientID = bundledConfiguration.clientID
        } else {
            clientID = ""
        }
    }

    var configuration: SpotifyConfiguration {
        SpotifyConfiguration(
            clientID: clientID,
            redirectURI: bundledConfiguration.redirectURI,
            scopes: bundledConfiguration.scopes
        )
    }

    var redirectURI: String { bundledConfiguration.redirectURI }
    var isConfigured: Bool { configuration.isConfigured }

    func save(clientID newValue: String) throws {
        let candidate = SpotifyConfiguration(
            clientID: newValue,
            redirectURI: bundledConfiguration.redirectURI,
            scopes: bundledConfiguration.scopes
        )
        try candidate.validate()
        clientID = candidate.clientID
        defaults.set(candidate.clientID, forKey: Key.clientID)
    }

    func clear() {
        defaults.removeObject(forKey: Key.clientID)
        clientID = bundledConfiguration.isConfigured ? bundledConfiguration.clientID : ""
    }

    var maskedClientID: String {
        guard clientID.count > 8 else {
            return clientID.isEmpty ? "Non configurato" : clientID
        }
        return "\(clientID.prefix(4))••••\(clientID.suffix(4))"
    }
}
