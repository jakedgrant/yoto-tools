import Foundation
import Testing
@testable import YotoTools

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func append(_ request: URLRequest) { lock.withLock { requests.append(request) } }
    var all: [URLRequest] { lock.withLock { requests } }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { defer { value += 1 }; return value } }
}

@MainActor
@Suite(.serialized)
struct YotoAPIClientTests {
    private func makeClient(auth: MockAuthProvider = MockAuthProvider()) -> YotoAPIClient {
        YotoAPIClient(
            auth: auth,
            baseURL: URL(string: "https://api.yotoplay.com")!,
            session: StubURLProtocol.makeSession())
    }

    @Test func getMyContentDecodesCardsAndSendsBearer() async throws {
        let log = RequestLog()
        StubURLProtocol.handler = { request in
            log.append(request)
            return StubURLProtocol.json(Fixtures.myContent())
        }
        defer { StubURLProtocol.handler = nil }

        let cards = try await makeClient().getMyContent()
        #expect(cards.count == 1)
        #expect(cards.first?.id == "CARD1")
        #expect(cards.first?.coverImageURL?.absoluteString == "https://example.com/cover.png")

        let request = try #require(log.all.first)
        #expect(request.url?.path == "/content/mine")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
    }

    @Test func getContentParsesChapters() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Stub(
                statusCode: 200,
                data: Data(Fixtures.cardJSON.utf8),
                headers: ["Content-Type": "application/json"])
        }
        defer { StubURLProtocol.handler = nil }

        let card = try await makeClient().getContent(cardId: "CARD1")
        #expect(card.title == "Bedtime Stories")
        #expect(card.chapters.count == 1)
        #expect(card.chapters.first?.tracks.count == 2)
        #expect(card.chapters.first?.tracks.last?.hasCustomIcon == false)
    }

    @Test func unauthorizedTriggersRefreshAndRetry() async throws {
        let auth = MockAuthProvider(token: "access-1", refreshedToken: "access-2")
        let counter = Counter()
        let log = RequestLog()
        StubURLProtocol.handler = { request in
            log.append(request)
            if counter.next() == 0 {
                return StubURLProtocol.Stub(statusCode: 401, data: Data(), headers: [:])
            }
            return StubURLProtocol.json(Fixtures.myContent())
        }
        defer { StubURLProtocol.handler = nil }

        let cards = try await makeClient(auth: auth).getMyContent()
        #expect(cards.count == 1)
        #expect(auth.forceRefreshCount == 1)
        #expect(log.all.count == 2)
        #expect(log.all.last?.value(forHTTPHeaderField: "Authorization") == "Bearer access-2")
    }

    @Test func httpErrorIsSurfaced() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Stub(statusCode: 500, data: Data("boom".utf8), headers: [:])
        }
        defer { StubURLProtocol.handler = nil }

        await #expect(throws: APIError.http(status: 500, body: "boom")) {
            _ = try await makeClient().getMyContent()
        }
    }

    @Test func getUserIconsDecodesAndSendsBearer() async throws {
        let log = RequestLog()
        StubURLProtocol.handler = { request in
            log.append(request)
            return StubURLProtocol.json(Fixtures.userIcons(["ICON-1", "ICON-2"]))
        }
        defer { StubURLProtocol.handler = nil }

        let icons = try await makeClient().getUserIcons()
        #expect(icons.map(\.mediaId) == ["ICON-1", "ICON-2"])
        #expect(icons.first?.url?.absoluteString == "https://example.com/icons/ICON-1.png")
        // Fractional-seconds ISO 8601 timestamps parse.
        #expect(icons.first?.createdAt != nil)

        let request = try #require(log.all.first)
        #expect(request.url?.path == "/media/displayIcons/user/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
    }

    @Test func getUserIconsToleratesMissingOptionalFields() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.json(["displayIcons": [["mediaId": "BARE"]]])
        }
        defer { StubURLProtocol.handler = nil }

        let icons = try await makeClient().getUserIcons()
        #expect(icons == [UserIcon(mediaId: "BARE")])
    }

    @Test func uploadIconUsesPNGContentTypeAndQuery() async throws {
        let log = RequestLog()
        StubURLProtocol.handler = { request in
            log.append(request)
            return StubURLProtocol.json(["displayIcon": ["mediaId": "MEDIA-123"]])
        }
        defer { StubURLProtocol.handler = nil }

        let mediaId = try await makeClient().uploadIcon(
            pngData: Data([1, 2, 3]),
            filename: "my-icon",
            autoConvert: false)
        #expect(mediaId == "MEDIA-123")

        let request = try #require(log.all.first)
        #expect(request.url?.path == "/media/displayIcons/user/me/upload")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/png")
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) })
        #expect(dict["autoConvert"] == "false")
        #expect(dict["filename"] == "my-icon")
    }
}
