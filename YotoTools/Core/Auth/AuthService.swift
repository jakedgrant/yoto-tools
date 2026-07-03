import Foundation

/// Token-providing seam consumed by the API client.
protocol AuthProviding: Sendable {
    /// Returns a non-expired access token, refreshing if necessary.
    func validAccessToken() async throws -> String
    /// Forces a refresh regardless of expiry (used after a 401) and returns the new token.
    func forceRefresh() async throws -> String
}

enum AuthError: Error, Equatable {
    case notSignedIn
    case missingRefreshToken
    case missingClientID
    case invalidCallback
    case stateMismatch
    case tokenRequest(status: Int)
}

enum AuthStatus: Equatable, Sendable {
    case signedOut
    case signingIn
    case signedIn
}

/// Owns the OAuth lifecycle: sign in (PKCE), persisted token state, refresh, sign out.
///
/// `@MainActor` so it can drive UI directly while also serializing token access.
/// Concurrent refreshes are de-duplicated via a single in-flight `Task`.
@MainActor
@Observable
final class AuthService: AuthProviding {
    private(set) var status: AuthStatus = .signedOut

    private let config: OAuthConfig
    private let tokenStore: TokenStoring
    private let webAuth: WebAuthenticating
    private let session: URLSession
    private let dateProvider: DateProvider
    private let ephemeralSession: Bool

    private var tokens: OAuthTokens?
    private var refreshTask: Task<OAuthTokens, Error>?

    init(
        config: OAuthConfig,
        tokenStore: TokenStoring,
        webAuth: WebAuthenticating,
        session: URLSession = .shared,
        dateProvider: DateProvider = .live,
        ephemeralSession: Bool = false
    ) {
        self.config = config
        self.tokenStore = tokenStore
        self.webAuth = webAuth
        self.session = session
        self.dateProvider = dateProvider
        self.ephemeralSession = ephemeralSession
    }

    var isSignedIn: Bool { status == .signedIn }

    /// Loads any persisted tokens on launch.
    func restore() async {
        if let stored = await tokenStore.load() {
            tokens = stored
            status = .signedIn
        } else {
            status = .signedOut
        }
    }

    func signIn() async throws {
        guard !config.clientID.isEmpty else { throw AuthError.missingClientID }
        status = .signingIn
        do {
            let pkce = PKCE.generate()
            let state = UUID().uuidString
            let authURL = config.authorizationURL(pkce: pkce, state: state)
            let callback = try await webAuth.authenticate(
                url: authURL,
                callbackScheme: config.callbackScheme,
                ephemeral: ephemeralSession)
            let code = try authorizationCode(from: callback, expectedState: state)
            let newTokens = try await exchange(code: code, verifier: pkce.verifier)
            try await persist(newTokens)
            status = .signedIn
        } catch {
            status = tokens == nil ? .signedOut : .signedIn
            throw error
        }
    }

    func signOut() async {
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        try? await tokenStore.clear()
        status = .signedOut
    }

    // MARK: AuthProviding

    func validAccessToken() async throws -> String {
        guard let current = tokens else { throw AuthError.notSignedIn }
        if current.isExpired(now: dateProvider.now()) {
            return try await refresh().accessToken
        }
        return current.accessToken
    }

    func forceRefresh() async throws -> String {
        try await refresh().accessToken
    }

    // MARK: - Internals

    private func refresh() async throws -> OAuthTokens {
        if let task = refreshTask {
            return try await task.value
        }
        guard let refreshToken = tokens?.refreshToken else {
            throw AuthError.missingRefreshToken
        }
        let task = Task { () throws -> OAuthTokens in
            let refreshed = try await requestToken(parameters: [
                "grant_type": "refresh_token",
                "client_id": config.clientID,
                "refresh_token": refreshToken,
            ])
            try await persist(refreshed)
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch {
            // A failed refresh means the session is no longer valid.
            tokens = nil
            try? await tokenStore.clear()
            status = .signedOut
            throw error
        }
    }

    private func exchange(code: String, verifier: String) async throws -> OAuthTokens {
        try await requestToken(parameters: [
            "grant_type": "authorization_code",
            "client_id": config.clientID,
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": verifier,
        ])
    }

    private func requestToken(parameters: [String: String]) async throws -> OAuthTokens {
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded(parameters).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AuthError.tokenRequest(status: status)
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return decoded.tokens(now: dateProvider.now(), previousRefreshToken: tokens?.refreshToken)
    }

    private func persist(_ newTokens: OAuthTokens) async throws {
        tokens = newTokens
        try await tokenStore.save(newTokens)
    }

    private func authorizationCode(from callback: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw AuthError.invalidCallback
        }
        if let returnedState = items.first(where: { $0.name == "state" })?.value,
           returnedState != expectedState {
            throw AuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.invalidCallback
        }
        return code
    }

    private static func formURLEncoded(_ parameters: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return parameters
            .map { key, value in
                let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
    }
}
