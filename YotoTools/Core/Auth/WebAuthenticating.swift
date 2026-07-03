import AuthenticationServices
import Foundation
import UIKit

/// Seam over `ASWebAuthenticationSession` so auth logic can be unit-tested without UI.
protocol WebAuthenticating: Sendable {
    /// Presents the authorization URL and resolves with the redirect callback URL.
    func authenticate(url: URL, callbackScheme: String, ephemeral: Bool) async throws -> URL
}

enum WebAuthError: Error, Equatable {
    case cancelled
    case noCallbackURL
    case presentationFailed
}

/// Live implementation backed by `ASWebAuthenticationSession`.
@MainActor
final class WebAuthenticator: NSObject, WebAuthenticating {
    func authenticate(url: URL, callbackScheme: String, ephemeral: Bool) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme) { callbackURL, error in
                    if let error {
                        if let asError = error as? ASWebAuthenticationSessionError,
                           asError.code == .canceledLogin {
                            continuation.resume(throwing: WebAuthError.cancelled)
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    guard let callbackURL else {
                        continuation.resume(throwing: WebAuthError.noCallbackURL)
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = ephemeral
            if !session.start() {
                continuation.resume(throwing: WebAuthError.presentationFailed)
            }
        }
    }
}

extension WebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = scene?.keyWindow ?? scene?.windows.first {
            return window
        }
        guard let scene else {
            preconditionFailure("No window scene available to present authentication")
        }
        return UIWindow(windowScene: scene)
    }
}
