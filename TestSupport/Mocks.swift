import Foundation
@testable import YotoTools

/// Web-auth seam that synthesizes a callback URL, echoing back the request's `state`.
final class MockWebAuthenticator: WebAuthenticating, @unchecked Sendable {
    var code: String?
    var error: Error?
    var stateOverride: String?
    private(set) var lastURL: URL?

    init(code: String? = "auth-code", error: Error? = nil) {
        self.code = code
        self.error = error
    }

    func authenticate(url: URL, callbackScheme: String, ephemeral: Bool) async throws -> URL {
        lastURL = url
        if let error { throw error }
        let incomingState = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "state" }?.value
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = "callback"
        var items = [URLQueryItem(name: "state", value: stateOverride ?? incomingState)]
        if let code { items.append(URLQueryItem(name: "code", value: code)) }
        components.queryItems = items
        return components.url!
    }
}

/// Token-providing seam for API client tests.
@MainActor
final class MockAuthProvider: AuthProviding {
    var token: String
    var refreshedToken: String
    var validError: Error?
    private(set) var forceRefreshCount = 0

    init(token: String = "access-1", refreshedToken: String = "access-2") {
        self.token = token
        self.refreshedToken = refreshedToken
    }

    func validAccessToken() async throws -> String {
        if let validError { throw validError }
        return token
    }

    func forceRefresh() async throws -> String {
        forceRefreshCount += 1
        token = refreshedToken
        return refreshedToken
    }
}

/// In-memory Yoto API with recorded interactions and configurable responses.
@MainActor
final class MockYotoAPI: YotoAPI {
    var cards: [CardSummary] = []
    var cardsByID: [String: CardDetail] = [:]
    var uploadMediaId = "MEDIA-NEW"
    var userIcons: [UserIcon] = []
    var uploadError: Error?
    var updateError: Error?
    var getContentError: Error?
    var getUserIconsError: Error?

    private(set) var uploads: [(data: Data, filename: String, autoConvert: Bool)] = []
    private(set) var updatedCards: [CardDetail] = []
    private(set) var requestedCardIDs: [String] = []
    private(set) var getUserIconsCallCount = 0

    func getMyContent() async throws -> [CardSummary] { cards }

    func getContent(cardId: String) async throws -> CardDetail {
        requestedCardIDs.append(cardId)
        if let getContentError { throw getContentError }
        guard let card = cardsByID[cardId] else { throw APIError.http(status: 404, body: nil) }
        return card
    }

    func updateContent(_ card: CardDetail) async throws -> CardDetail {
        if let updateError { throw updateError }
        updatedCards.append(card)
        return card
    }

    func uploadIcon(pngData: Data, filename: String, autoConvert: Bool) async throws -> String {
        if let uploadError { throw uploadError }
        uploads.append((pngData, filename, autoConvert))
        // Mirror the real server: a successful upload appears in the user's icon list.
        userIcons.append(UserIcon(mediaId: uploadMediaId))
        return uploadMediaId
    }

    func getUserIcons() async throws -> [UserIcon] {
        getUserIconsCallCount += 1
        if let getUserIconsError { throw getUserIconsError }
        return userIcons
    }
}
