import Foundation

/// Static configuration for the Yoto OAuth2 (Auth0) flow.
struct OAuthConfig: Sendable, Equatable {
    var clientID: String
    var redirectURI: String
    var callbackScheme: String
    var authorizationEndpoint: URL
    var tokenEndpoint: URL
    var audience: String
    var scopes: [String]

    var scopeString: String { scopes.joined(separator: " ") }

    /// The production Yoto endpoints. Only the client ID is user-supplied.
    static func standard(clientID: String) -> OAuthConfig {
        OAuthConfig(
            clientID: clientID,
            redirectURI: "yototools://callback",
            callbackScheme: "yototools",
            authorizationEndpoint: URL(string: "https://login.yotoplay.com/authorize")!,
            tokenEndpoint: URL(string: "https://login.yotoplay.com/oauth/token")!,
            audience: "https://api.yotoplay.com",
            scopes: [
                "user:content:view",
                "user:content:manage",
                "user:icons:manage",
                "offline_access",
            ])
    }

    /// Builds the `/authorize` URL for a PKCE public client.
    func authorizationURL(pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "audience", value: audience),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.method),
        ]
        return components.url!
    }
}
