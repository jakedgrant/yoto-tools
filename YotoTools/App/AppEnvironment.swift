import Foundation
import SwiftUI

/// Composition root. Builds and owns the app's services, and rebuilds the auth/API
/// stack when the user changes the configured Yoto client id.
@MainActor
@Observable
final class AppEnvironment {
    private(set) var auth: AuthService
    private(set) var api: any YotoAPI

    private(set) var clientID: String
    var usesEphemeralSession: Bool {
        didSet {
            defaults.set(usesEphemeralSession, forKey: Keys.ephemeral)
            rebuildServices()
        }
    }

    private let defaults: UserDefaults
    private let webAuth: WebAuthenticating

    private enum Keys {
        static let clientID = "yoto.clientID"
        static let ephemeral = "yoto.ephemeralSession"
    }

    init(defaults: UserDefaults = .standard, webAuth: WebAuthenticating? = nil) {
        let resolvedWebAuth = webAuth ?? WebAuthenticator()
        let resolvedClientID = defaults.string(forKey: Keys.clientID) ?? ""
        let resolvedEphemeral = defaults.bool(forKey: Keys.ephemeral)

        self.defaults = defaults
        self.webAuth = resolvedWebAuth
        self.clientID = resolvedClientID
        self.usesEphemeralSession = resolvedEphemeral

        let auth = AuthService(
            config: .standard(clientID: resolvedClientID),
            tokenStore: KeychainTokenStore(),
            webAuth: resolvedWebAuth,
            ephemeralSession: resolvedEphemeral)
        self.auth = auth
        self.api = YotoAPIClient(auth: auth)
    }

    var hasClientID: Bool { !clientID.isEmpty }

    func updateClientID(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != clientID else { return }
        clientID = trimmed
        defaults.set(trimmed, forKey: Keys.clientID)
        rebuildServices()
        Task { await auth.restore() }
    }

    /// Loads any persisted session at launch.
    func bootstrap() async {
        await auth.restore()
    }

    private func rebuildServices() {
        let config = OAuthConfig.standard(clientID: clientID)
        let newAuth = AuthService(
            config: config,
            tokenStore: KeychainTokenStore(),
            webAuth: webAuth,
            ephemeralSession: usesEphemeralSession)
        auth = newAuth
        api = YotoAPIClient(auth: newAuth)
    }
}
