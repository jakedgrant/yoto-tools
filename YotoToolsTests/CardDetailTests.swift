import Foundation
import Testing
@testable import YotoTools

struct JSONValueTests {
    @Test func roundTripsThroughCoding() throws {
        let data = Data(Fixtures.cardJSON.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let reencoded = try JSONEncoder().encode(value)
        let again = try JSONDecoder().decode(JSONValue.self, from: reencoded)
        #expect(value == again)
    }

    @Test func setCreatesNestedPath() {
        var value = JSONValue.object([:])
        value.set(.string("hi"), at: [.key("a"), .key("b")])
        #expect(value["a"]?["b"]?.stringValue == "hi")
    }

    @Test func setIgnoresOutOfRangeIndex() {
        var value = JSONValue.object(["list": .array([.string("x")])])
        value.set(.string("y"), at: [.key("list"), .index(5)])
        #expect(value["list"]?.arrayValue?.count == 1)
    }
}

struct CardDetailTests {
    @Test func setTrackIconTargetsCorrectTrackAndPreservesOthers() {
        var card = Fixtures.card()
        card.setTrackIcon(chapterIndex: 0, trackIndex: 1, mediaId: "NEWMEDIA")

        let tracks = try! #require(card.chapters.first?.tracks)
        #expect(tracks[1].iconRef == "yoto:#NEWMEDIA")
        // The other track keeps its original icon.
        #expect(tracks[0].iconRef == "yoto:#OLDICON")
        // Titles untouched.
        #expect(tracks[0].title == "The Moon")
        #expect(tracks[1].title == "The Stars")
    }

    @Test func encodedBodyKeepsWritableFieldsAndDropsServerFields() throws {
        var card = Fixtures.card()
        card.setTrackIcon(chapterIndex: 0, trackIndex: 1, mediaId: "NEWMEDIA")
        let body = try card.encodedBody()
        let decoded = try JSONDecoder().decode(JSONValue.self, from: body)

        #expect(decoded["cardId"]?.stringValue == "CARD1")
        #expect(decoded["title"]?.stringValue == "Bedtime Stories")
        #expect(decoded["metadata"]?["author"]?.stringValue == "Jane")
        // Writable content (including the new icon) is preserved...
        let track = decoded["content"]?["chapters"]?.arrayValue?[0]["tracks"]?.arrayValue?[1]
        let icon = track?["display"]?["icon16x16"]?.stringValue
        #expect(icon == "yoto:#NEWMEDIA")
        // ...but server-managed fields are not sent back.
        #expect(decoded["userId"] == nil)
        #expect(decoded["createdAt"] == nil)
    }

    @Test func summaryDecodesCoverImage() throws {
        let data = try JSONSerialization.data(withJSONObject: Fixtures.myContent())
        let response = try JSONDecoder().decode(MyContentResponse.self, from: data)
        #expect(response.cards.first?.title == "Bedtime Stories")
        #expect(response.cards.first?.coverImageURL?.absoluteString == "https://example.com/cover.png")
    }
}
