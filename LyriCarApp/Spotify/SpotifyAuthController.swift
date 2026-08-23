import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class SpotifyAuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let configurationProvider: () -> SpotifyConfiguration
    private let tokenStore: SpotifyTokenStoring
    private var webAuthenticationSession: ASWebAuthenticationSession?

    init(
        configurationProvider: @escaping () -> SpotifyConfiguration,
        tokenStore: SpotifyTokenStoring
    ) {
        self.configurationProvider = configurationProvider
        self.tokenStore = tokenStore
    }

    var hasStoredToken: Bool {
        (try? tokenStore.load()) != nil
    }

    func authenticate() async throws -> SpotifyToken {
        let configuration = configurationProvider()
        try configuration.validate()

        let verifier = Self.randomURLSafeString(byteCount: 64)
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafeString(byteCount: 24)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "show_dialog", value: "false")
        ]
        guard let authorizationURL = components.url else {
            throw SpotifyConfigurationError.invalidRedirectURL
        }

        let callbackURL = try await startWebAuthentication(
            url: authorizationURL,
            callbackScheme: URL(string: configuration.redirectURI)?.scheme
        )
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw SpotifyAuthError.invalidCallback
        }
        let values = Dictionary(uniqueKeysWithValues: callbackComponents.queryItems?.compactMap { item in
            item.value.map { (item.name, $0) }
        } ?? [])
        if let message = values["error"] { throw SpotifyAuthError.authorizationDenied(message) }
        guard values["state"] == state else { throw SpotifyAuthError.stateMismatch }
        guard let code = values["code"], !code.isEmpty else { throw SpotifyAuthError.missingCode }

        let response: SpotifyTokenResponse = try await tokenRequest(parameters: [
            "client_id": configuration.clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "code_verifier": verifier
        ])
        let token = response.token()
        try tokenStore.save(token)
        return token
    }

    func validToken(forceRefresh: Bool = false) async throws -> SpotifyToken {
        let configuration = configurationProvider()
        try configuration.validate()

        guard var token = try tokenStore.load() else { throw SpotifyAuthError.notAuthenticated }
        guard forceRefresh || token.needsRefresh else { return token }
        guard let refreshToken = token.refreshToken else {
            try? tokenStore.clear()
            throw SpotifyAuthError.notAuthenticated
        }
        let response: SpotifyTokenResponse = try await tokenRequest(parameters: [
            "client_id": configuration.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])
        token = response.token(preservingRefreshToken: refreshToken)
        try tokenStore.save(token)
        return token
    }

    func disconnect() throws {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        try tokenStore.clear()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    private func startWebAuthentication(url: URL, callbackScheme: String?) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] url, error in
                self?.webAuthenticationSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: SpotifyAuthError.invalidCallback)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webAuthenticationSession = session
            guard session.start() else {
                webAuthenticationSession = nil
                continuation.resume(throwing: SpotifyAuthError.couldNotStartSession)
                return
            }
        }
    }

    private func tokenRequest<T: Decodable>(parameters: [String: String]) async throws -> T {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded(parameters)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SpotifyAuthError.tokenExchangeFailed(body)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func formEncoded(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var data = Data(count: byteCount)
        let status = data.withUnsafeMutableBytes { bytes in
            guard let address = bytes.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, byteCount, address)
        }
        precondition(status == errSecSuccess, "Impossibile generare entropia sicura")
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum SpotifyAuthError: LocalizedError {
    case invalidCallback
    case stateMismatch
    case missingCode
    case authorizationDenied(String)
    case notAuthenticated
    case invalidResponse
    case tokenExchangeFailed(String)
    case couldNotStartSession

    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "Callback Spotify non valido."
        case .stateMismatch: return "La risposta Spotify non supera il controllo di sicurezza."
        case .missingCode: return "Spotify non ha restituito il codice di autorizzazione."
        case .authorizationDenied(let value): return "Autorizzazione Spotify negata: \(value)."
        case .notAuthenticated: return "Spotify non collegata."
        case .invalidResponse: return "Risposta Spotify non valida."
        case .tokenExchangeFailed(let value): return "Scambio token Spotify non riuscito: \(value)."
        case .couldNotStartSession: return "Impossibile aprire la schermata di accesso Spotify."
        }
    }
}
