import Foundation

enum APIErrorFormatter {
    static func message(_ error: Error) -> String {
        switch error {
        case AuthError.notSignedIn, AuthError.missingClientID:
            return "Please sign in to your Yoto account first."
        case AuthError.missingRefreshToken:
            return "Your session expired. Please sign in again."
        case AuthError.tokenRequest(let status):
            return "Sign-in failed (\(status))."
        case APIError.http(let status, _):
            if status == 401 || status == 403 {
                return "You don't have permission, or your session expired."
            }
            return "The Yoto service returned an error (\(status))."
        case APIError.decoding:
            return "Received an unexpected response from Yoto."
        default:
            return error.localizedDescription
        }
    }
}
