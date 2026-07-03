import Foundation

/// A `URLProtocol` that answers requests from an injected handler, for offline
/// network tests. Set `StubURLProtocol.handler` before each test.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        var statusCode: Int
        var data: Data
        var headers: [String: String]
    }

    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Stub)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let stub = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// A URLSession wired to use only this stub protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func json(_ object: Any, status: Int = 200) -> Stub {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return Stub(statusCode: status, data: data, headers: ["Content-Type": "application/json"])
    }
}
