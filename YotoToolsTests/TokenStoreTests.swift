import Foundation
import Testing
@testable import YotoTools

struct TokenStoreTests {
    @Test func inMemoryStoreRoundTrips() async throws {
        let store = InMemoryTokenStore()
        #expect(await store.load() == nil)

        let tokens = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSince1970: 1000),
            scope: "s")
        try await store.save(tokens)
        #expect(await store.load() == tokens)

        try await store.clear()
        #expect(await store.load() == nil)
    }

    @Test func tokenResponseCarriesForwardRefreshTokenWhenOmitted() {
        let now = Date(timeIntervalSince1970: 0)
        let response = TokenResponse(
            accessToken: "new-access",
            refreshToken: nil,
            expiresIn: 3600,
            scope: nil,
            tokenType: "Bearer")
        let tokens = response.tokens(now: now, previousRefreshToken: "old-refresh")
        #expect(tokens.refreshToken == "old-refresh")
        #expect(tokens.expiresAt == now.addingTimeInterval(3600))
    }

    @Test func expiryRespectsLeeway() {
        let now = Date(timeIntervalSince1970: 1000)
        let tokens = OAuthTokens(
            accessToken: "a",
            refreshToken: nil,
            expiresAt: now.addingTimeInterval(30),
            scope: nil)
        // Expires in 30s but the 60s leeway treats it as already expired.
        #expect(tokens.isExpired(now: now))
        #expect(!tokens.isExpired(now: now, leeway: 0))
    }
}
