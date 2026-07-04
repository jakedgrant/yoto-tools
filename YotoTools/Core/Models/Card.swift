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
        self.id = try container.decode(String.self, forKey: .cardId)
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"

        var cover: URL?
        if let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata),
           let coverContainer = try? metadata.nestedContainer(keyedBy: CoverKeys.self, forKey: .cover),
           let imageString = try? coverContainer.decode(String.self, forKey: .imageL) {
            cover = URL(string: imageString)
        }
        self.coverImageURL = cover
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

    /// Removes a track's custom `display.icon16x16`, restoring the player's default.
    mutating func clearTrackIcon(chapterIndex: Int, trackIndex: Int) {
        json.remove(at: [
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

/// One icon from the display-icon listing endpoints — the user's own uploads
/// (`GET /media/displayIcons/user/me`) or Yoto's public library
/// (`GET /media/displayIcons/user/yoto`, which adds `title` and `publicTags`).
/// Only `mediaId` is required; the rest is tolerated defensively like `CardSummary`.
struct DisplayIcon: Identifiable, Hashable, Sendable, Decodable {
    let mediaId: String
    let url: URL?
    let title: String?
    let createdAt: Date?
    let publicTags: [String]

    var id: String { mediaId }

    private enum CodingKeys: String, CodingKey { case mediaId, url, title, createdAt, publicTags }

    init(
        mediaId: String,
        url: URL? = nil,
        title: String? = nil,
        createdAt: Date? = nil,
        publicTags: [String] = []
    ) {
        self.mediaId = mediaId
        self.url = url
        self.title = title
        self.createdAt = createdAt
        self.publicTags = publicTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaId = try container.decode(String.self, forKey: .mediaId)
        self.url = (try? container.decode(String.self, forKey: .url)).flatMap(URL.init(string:))
        self.title = try? container.decode(String.self, forKey: .title)
        self.publicTags = (try? container.decode([String].self, forKey: .publicTags)) ?? []
        // Timestamps arrive as ISO 8601 with fractional seconds; accept both variants.
        let timestamp = try? container.decode(String.self, forKey: .createdAt)
        self.createdAt = timestamp.flatMap { string in
            (try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
                ?? (try? Date(string, strategy: .iso8601))
        }
    }
}

/// Response envelope shared by the display-icon listing endpoints.
struct DisplayIconsResponse: Decodable, Sendable {
    let displayIcons: [DisplayIcon]
}
