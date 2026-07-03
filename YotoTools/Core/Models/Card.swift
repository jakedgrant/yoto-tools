import Foundation

/// Lightweight summary from `GET /content/mine` (no chapters/tracks).
struct CardSummary: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let title: String
    let coverImageURL: URL?

    enum CodingKeys: String, CodingKey { case cardId, title, metadata }
    private enum MetadataKeys: String, CodingKey { case cover }
    private enum CoverKeys: String, CodingKey { case imageL }

    init(id: String, title: String, coverImageURL: URL?) {
        self.id = id
        self.title = title
        self.coverImageURL = coverImageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .cardId)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"

        var cover: URL?
        if let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata),
           let coverContainer = try? metadata.nestedContainer(keyedBy: CoverKeys.self, forKey: .cover),
           let imageString = try? coverContainer.decode(String.self, forKey: .imageL) {
            cover = URL(string: imageString)
        }
        coverImageURL = cover
    }
}

struct MyContentResponse: Decodable, Sendable {
    let cards: [CardSummary]
}

/// Full card payload from `GET /content/{cardId}`, preserved as raw JSON so updates
/// don't drop fields we don't model.
struct CardDetail: Sendable, Equatable {
    var json: JSONValue

    init(json: JSONValue) {
        self.json = json
    }

    /// Decodes a response that may be the card object directly or wrapped as `{ "card": {...} }`.
    static func decode(from data: Data) throws -> CardDetail {
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        if case .object(let object) = value, let card = object["card"] {
            return CardDetail(json: card)
        }
        return CardDetail(json: value)
    }

    var cardId: String? { json["cardId"]?.stringValue }
    var title: String { json["title"]?.stringValue ?? "Untitled" }

    var coverImageURL: URL? {
        guard let string = json["metadata"]?["cover"]?["imageL"]?.stringValue else { return nil }
        return URL(string: string)
    }

    /// A flattened, display-ready view of the card's chapters and tracks.
    var chapters: [ChapterView] {
        let rawChapters = json["content"]?["chapters"]?.arrayValue ?? []
        return rawChapters.enumerated().map { chapterIndex, chapter in
            let rawTracks = chapter["tracks"]?.arrayValue ?? []
            let tracks = rawTracks.enumerated().map { trackIndex, track -> TrackView in
                let iconURLString = track["display"]?["iconUrl16x16"]?.stringValue
                return TrackView(
                    chapterIndex: chapterIndex,
                    trackIndex: trackIndex,
                    key: track["key"]?.stringValue,
                    title: track["title"]?.stringValue ?? "Track \(trackIndex + 1)",
                    iconRef: track["display"]?["icon16x16"]?.stringValue,
                    iconURL: iconURLString.flatMap(URL.init(string:)))
            }
            return ChapterView(
                index: chapterIndex,
                title: chapter["title"]?.stringValue ?? "Chapter \(chapterIndex + 1)",
                tracks: tracks)
        }
    }

    /// Points a track's `display.icon16x16` at an uploaded media id (`yoto:#<mediaId>`).
    mutating func setTrackIcon(chapterIndex: Int, trackIndex: Int, mediaId: String) {
        json.set(.string("yoto:#\(mediaId)"), at: [
            .key("content"), .key("chapters"), .index(chapterIndex),
            .key("tracks"), .index(trackIndex), .key("display"), .key("icon16x16"),
        ])
    }

    /// The body sent to `POST /content`: only the writable top-level fields, with
    /// their full subtrees preserved.
    func encodedBody() throws -> Data {
        var body: [String: JSONValue] = [:]
        for key in ["cardId", "title", "content", "metadata"] {
            if let value = json[key] {
                body[key] = value
            }
        }
        return try JSONEncoder().encode(JSONValue.object(body))
    }
}

struct ChapterView: Identifiable, Hashable, Sendable {
    let index: Int
    let title: String
    let tracks: [TrackView]
    var id: Int { index }
}

struct TrackView: Identifiable, Hashable, Sendable {
    let chapterIndex: Int
    let trackIndex: Int
    let key: String?
    let title: String
    let iconRef: String?
    let iconURL: URL?
    var id: String { "\(chapterIndex)-\(trackIndex)" }
    var hasCustomIcon: Bool { iconRef != nil }
}

/// Response from the custom icon upload endpoint.
struct UploadIconResponse: Decodable, Sendable {
    let displayIcon: DisplayIcon

    struct DisplayIcon: Decodable, Sendable {
        let mediaId: String
    }
}
