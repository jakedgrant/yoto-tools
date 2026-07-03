import Foundation
import Testing
@testable import YotoTools

@MainActor
struct IconAssignmentServiceTests {
    @Test func assignUploadsPNGAndWritesIconToTheRightTrack() async throws {
        let api = MockYotoAPI()
        api.uploadMediaId = "MEDIA-NEW"
        let service = IconAssignmentService(api: api)

        let card = Fixtures.card()
        let track = try #require(card.chapters.first?.tracks.last) // "The Stars", no icon
        var grid = PixelGrid()
        grid.setColor(.black, x: 0, y: 0)

        let result = try await service.assign(
            grid: grid,
            to: track,
            in: card,
            filename: "stars",
            autoConvert: false)

        #expect(result.mediaId == "MEDIA-NEW")

        // Upload happened once, as PNG, non-converted.
        #expect(api.uploads.count == 1)
        #expect(api.uploads.first?.filename == "stars")
        #expect(api.uploads.first?.autoConvert == false)

        // The updated card targeted the correct track and preserved the other.
        let updated = try #require(api.updatedCards.last)
        let tracks = try #require(updated.chapters.first?.tracks)
        #expect(tracks[1].iconRef == "yoto:#MEDIA-NEW")
        #expect(tracks[0].iconRef == "yoto:#OLDICON")
        #expect(updated.title == "Bedtime Stories")
    }

    @Test func uploadFailureLeavesNoUpdate() async throws {
        let api = MockYotoAPI()
        api.uploadError = APIError.http(status: 500, body: nil)
        let service = IconAssignmentService(api: api)
        let card = Fixtures.card()
        let track = try #require(card.chapters.first?.tracks.first)

        await #expect(throws: APIError.http(status: 500, body: nil)) {
            _ = try await service.assign(grid: PixelGrid(), to: track, in: card, filename: "x")
        }
        #expect(api.updatedCards.isEmpty)
    }

    @Test func detailViewModelCachesMediaIdOnSuccess() async throws {
        let api = MockYotoAPI()
        api.uploadMediaId = "CACHED-ID"
        api.cardsByID = ["CARD1": Fixtures.card()]

        var cachedMediaId: String?
        let vm = CardDetailViewModel(
            api: api,
            cardId: "CARD1",
            grid: PixelGrid(),
            artName: "My Art",
            onAssigned: { cachedMediaId = $0 })

        await vm.load()
        let track = try #require(vm.card?.chapters.first?.tracks.last)
        await vm.assign(track: track)

        #expect(cachedMediaId == "CACHED-ID")
        #expect(vm.banner?.isError == false)
    }
}
