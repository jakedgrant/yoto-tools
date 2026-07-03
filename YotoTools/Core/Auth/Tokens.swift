import Foundation

/// OAuth tokens persisted between launches.
struct OAuthTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scope: String?

    /// True when the access token has expired (or is within `leeway` of expiring).
    func isExpired(now: Date, leeway: TimeInterval = 60) -> Bool {
        now >= expiresAt.addingTimeInterval(-leeway)
    }
}

/// The raw `/oauth/token` response body.
struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double
    let scope: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }

    /// Converts the response into stored tokens, carrying forward the previous
    /// refresh token when the server omits a new one.
    func tokens(now: Date, previousRefreshToken: String?) -> OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken ?? previousRefreshToken,
            expiresAt: now.addingTimeInterval(expiresIn),
            scope: scope)
    }
}
