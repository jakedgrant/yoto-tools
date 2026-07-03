import Foundation

enum APIError: Error, Equatable {
    case invalidResponse
    case http(status: Int, body: String?)
    case decoding(String)
    case missingField(String)
}
