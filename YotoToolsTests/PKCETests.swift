import CryptoKit
import Foundation
import Testing
@testable import YotoTools

struct PKCETests {
    @Test func challengeIsBase64URLSHA256OfVerifier() {
        let pkce = PKCE(verifier: "test-verifier-value")
        let expected = Data(SHA256.hash(data: Data("test-verifier-value".utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        #expect(pkce.challenge == expected)
        #expect(pkce.method == "S256")
    }

    @Test func generatedVerifierIsURLSafeAndCorrectLength() {
        let pkce = PKCE.generate()
        // 32 random bytes → 43-char base64url string (no padding).
        #expect(pkce.verifier.count == 43)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(pkce.verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test func generatedPairsAreUnique() {
        #expect(PKCE.generate().verifier != PKCE.generate().verifier)
    }
}

struct OAuthConfigTests {
    @Test func authorizationURLContainsRequiredParameters() throws {
        let config = OAuthConfig.standard(clientID: "client-xyz")
        let pkce = PKCE(verifier: "verifier")
        let url = config.authorizationURL(pkce: pkce, state: "state-123")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

        #expect(url.host == "login.yotoplay.com")
        #expect(dict["response_type"] == "code")
        #expect(dict["client_id"] == "client-xyz")
        #expect(dict["redirect_uri"] == "yototools://callback")
        #expect(dict["audience"] == "https://api.yotoplay.com")
        #expect(dict["code_challenge_method"] == "S256")
        #expect(dict["code_challenge"] == pkce.challenge)
        #expect(dict["state"] == "state-123")
        let scope = try #require(dict["scope"] ?? nil)
        #expect(scope.contains("user:content:manage"))
        #expect(scope.contains("offline_access"))
    }
}
