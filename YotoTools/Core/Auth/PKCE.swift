import CryptoKit
import Foundation

/// A PKCE verifier/challenge pair (RFC 7636, S256).
struct PKCE: Sendable, Equatable {
    let verifier: String
    let challenge: String
    let method = "S256"

    init(verifier: String) {
        self.verifier = verifier
        let digest = SHA256.hash(data: Data(verifier.utf8))
        self.challenge = Data(digest).base64URLEncodedString()
    }

    /// Generates a fresh pair from `byteCount` of cryptographic randomness
    /// (32 bytes → a 43-character base64url verifier).
    static func generate(byteCount: Int = 32) -> PKCE {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return PKCE(verifier: Data(bytes).base64URLEncodedString())
    }
}

extension Data {
    /// base64url without padding, per RFC 7636.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
