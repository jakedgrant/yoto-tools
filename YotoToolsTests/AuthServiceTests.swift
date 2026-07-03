import Foundation
import Testing
@testable import YotoTools

/// A thread-safe mutable box for sharing state with the `@Sendable` stub handler.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

@MainActor
@Suite(.serialized)
struct AuthServiceTests {
    private func makeService(
        tokens: OAuthTokens? = nil,
        webAuth: MockWebAuthenticator = MockWebAuthenticator(),
        now: Date = Date(timeIntervalSince1970: 1000)
    ) -> AuthService {
        AuthService(
            config: .standard(clientID: "client-1"),
            tokenStore: InMemoryTokenStore(tokens: tokens),
            webAuth: webAuth,
            session: StubURLProtocol.makeSession(),
            dateProvider: .fixed(now))
    }

    @Test func signInExchangesCodeAndPersistsTokens() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.json(Fixtures.tokenResponse(accessToken: "access-1", refreshToken: "refresh-1"))
        }
        defer { StubURLProtocol.handler = nil }

        let service = makeService()
        try await service.signIn()

        #expect(service.isSignedIn)
        #expect(try await service.validAccessToken() == "access-1")
    }

    @Test func refreshRotatesAndPersistsNewRefreshToken() async throws {
        let store = InMemoryTokenStore(tokens: OAuthTokens(
            accessToken: "expired",
            refreshToken: "refresh-1",
            expiresAt: Date(timeIntervalSince1970: 0),
            scope: nil))
        let service = AuthService(
            config: .standard(clientID: "client-1"),
            tokenStore: store,
            webAuth: MockWebAuthenticator(),
            session: StubURLProtocol.makeSession(),
            dateProvider: .fixed(Date(timeIntervalSince1970: 1000)))
        await service.restore()

        StubURLProtocol.handler = { _ in
            StubURLProtocol.json(Fixtures.tokenResponse(accessToken: "access-2", refreshToken: "refresh-2"))
        }
        defer { StubURLProtocol.handler = nil }

        let token = try await service.validAccessToken()
        #expect(token == "access-2")
        let persisted = await store.load()
        #expect(persisted?.refreshToken == "refresh-2")
    }

    @Test func concurrentRefreshesHitTheNetworkOnce() async throws {
        let store = InMemoryTokenStore(tokens: OAuthTokens(
            accessToken: "expired",
            refreshToken: "refresh-1",
            expiresAt: Date(timeIntervalSince1970: 0),
            scope: nil))
        let service = AuthService(
            config: .standard(clientID: "client-1"),
            tokenStore: store,
            webAuth: MockWebAuthenticator(),
            session: StubURLProtocol.makeSession(),
            dateProvider: .fixed(Date(timeIntervalSince1970: 1000)))
        await service.restore()

        let callCount = Box(0)
        StubURLProtocol.handler = { _ in
            callCount.value += 1
            return StubURLProtocol.json(Fixtures.tokenResponse(accessToken: "access-2", refreshToken: "refresh-2"))
        }
        defer { StubURLProtocol.handler = nil }

        async let a = service.validAccessToken()
        async let b = service.validAccessToken()
        let results = try await [a, b]

        #expect(results == ["access-2", "access-2"])
        #expect(callCount.value == 1)
    }

    @Test func signOutClearsSession() async throws {
        let service = makeService(tokens: OAuthTokens(
            accessToken: "a", refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 9_999_999), scope: nil))
        await service.restore()
        #expect(service.isSignedIn)

        await service.signOut()
        #expect(service.status == .signedOut)
        await #expect(throws: AuthError.notSignedIn) {
            _ = try await service.validAccessToken()
        }
    }

    @Test func signInRejectsMismatchedState() async throws {
        let webAuth = MockWebAuthenticator()
        webAuth.stateOverride = "tampered"
        let service = makeService(webAuth: webAuth)
        await #expect(throws: AuthError.stateMismatch) {
            try await service.signIn()
        }
        #expect(!service.isSignedIn)
    }
}
