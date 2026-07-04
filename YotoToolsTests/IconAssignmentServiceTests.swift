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

    @Test func assignReusesCachedMediaIdWhenServerStillHasIt() async throws {
        let api = MockYotoAPI()
        api.userIcons = [UserIcon(mediaId: "CACHED")]
        let service = IconAssignmentService(api: api)
        let card = Fixtures.card()
        let track = try #require(card.chapters.first?.tracks.last)

        let result = try await service.assign(
            grid: PixelGrid(),
            to: track,
            in: card,
            filename: "x",
            cachedMediaId: "CACHED")

        #expect(result.mediaId == "CACHED")
        #expect(api.uploads.isEmpty)
        let updated = try #require(api.updatedCards.last)
        #expect(updated.chapters.first?.tracks.last?.iconRef == "yoto:#CACHED")
    }

    @Test func assignUploadsFreshWhenCachedMediaIdIsGoneFromServer() async throws {
        let api = MockYotoAPI()
        api.userIcons = [] // the server no longer lists the cached upload
        api.uploadMediaId = "FRESH"
        let service = IconAssignmentService(api: api)
        let card = Fixtures.card()
        let track = try #require(card.chapters.first?.tracks.last)

        let result = try await service.assign(
            grid: PixelGrid(),
            to: track,
            in: card,
            filename: "x",
            cachedMediaId: "STALE")

        #expect(result.mediaId == "FRESH")
        #expect(api.uploads.count == 1)
    }

    @Test func assignUploadsFreshWhenIconLookupFails() async throws {
        let api = MockYotoAPI()
        api.getUserIconsError = APIError.http(status: 500, body: nil)
        api.uploadMediaId = "FRESH"
        let service = IconAssignmentService(api: api)
        let card = Fixtures.card()
        let track = try #require(card.chapters.first?.tracks.last)

        // The reuse check is only an optimization; its failure must not fail assignment.
        let result = try await service.assign(
            grid: PixelGrid(),
            to: track,
            in: card,
            filename: "x",
            cachedMediaId: "CACHED")

        #expect(result.mediaId == "FRESH")
        #expect(api.uploads.count == 1)
    }

    @Test func detailViewModelUploadsOnceAcrossTwoAssigns() async throws {
        let api = MockYotoAPI()
        api.uploadMediaId = "MEDIA-1"
        api.cardsByID = ["CARD1": Fixtures.card()]

        let vm = CardDetailViewModel(
            api: api,
            cardId: "CARD1",
            grid: PixelGrid(),
            artName: "My Art",
            onAssigned: { _ in })

        await vm.load()
        let tracks = try #require(vm.card?.chapters.first?.tracks)
        await vm.assign(track: tracks[0])
        await vm.assign(track: tracks[1])

        // The first assign uploads; the second reuses that upload for the same art.
        #expect(api.uploads.count == 1)
        let updated = try #require(api.updatedCards.last)
        #expect(updated.chapters.first?.tracks[1].iconRef == "yoto:#MEDIA-1")
        #expect(vm.banner?.isError == false)
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
