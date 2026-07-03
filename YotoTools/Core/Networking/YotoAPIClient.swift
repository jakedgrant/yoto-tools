import Foundation

/// Live Yoto API client. Injects a bearer token per request and retries once on a
/// 401 after forcing a token refresh.
actor YotoAPIClient: YotoAPI {
    private let baseURL: URL
    private let session: URLSession
    private let auth: AuthProviding

    init(
        auth: AuthProviding,
        baseURL: URL = URL(string: "https://api.yotoplay.com")!,
        session: URLSession = .shared
    ) {
        self.auth = auth
        self.baseURL = baseURL
        self.session = session
    }

    func getMyContent() async throws -> [CardSummary] {
        let request = try await authorized(makeRequest(path: "/content/mine"))
        let (data, _) = try await sendExpectingSuccess(request)
        do {
            return try JSONDecoder().decode(MyContentResponse.self, from: data).cards
        } catch {
            throw APIError.decoding("\(error)")
        }
    }

    func getContent(cardId: String) async throws -> CardDetail {
        let request = try await authorized(makeRequest(path: "/content/\(cardId)"))
        let (data, _) = try await sendExpectingSuccess(request)
        do {
            return try CardDetail.decode(from: data)
        } catch {
            throw APIError.decoding("\(error)")
        }
    }

    func updateContent(_ card: CardDetail) async throws -> CardDetail {
        var request = makeRequest(path: "/content")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try card.encodedBody()
        let (data, _) = try await sendExpectingSuccess(authorized(request))
        do {
            return try CardDetail.decode(from: data)
        } catch {
            throw APIError.decoding("\(error)")
        }
    }

    func uploadIcon(pngData: Data, filename: String, autoConvert: Bool) async throws -> String {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/media/displayIcons/user/me/upload"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "autoConvert", value: autoConvert ? "true" : "false"),
            URLQueryItem(name: "filename", value: filename),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.httpBody = pngData
        let (data, _) = try await sendExpectingSuccess(authorized(request))
        do {
            return try JSONDecoder().decode(UploadIconResponse.self, from: data).displayIcon.mediaId
        } catch {
            throw APIError.decoding("\(error)")
        }
    }

    // MARK: - Request plumbing

    private func makeRequest(path: String) -> URLRequest {
        URLRequest(url: baseURL.appendingPathComponent(path))
    }

    private func authorized(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let token = try await auth.validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Sends the request, retrying once with a forced token refresh on 401.
    private func sendExpectingSuccess(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var (data, response) = try await session.data(for: request)
        guard var http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 {
            var retry = request
            let token = try await auth.forceRefresh()
            retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            (data, response) = try await session.data(for: retry)
            guard let retried = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            http = retried
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return (data, http)
    }
}
