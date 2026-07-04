import Foundation
import SwiftData
import Testing
@testable import YotoTools

/// End-to-end happy path stitching the real view models together with the network
/// mock and an in-memory store: create a drawing in the editor, save it, then assign
/// it to a track exactly the way `PixelArtNavigator` wires the assign screen.
@MainActor
struct CreateSaveAssignFlowTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PixelArt.self, configurations: configuration)
        return ModelContext(container)
    }

    @Test func createSaveThenAssignUploadsIconAndCachesMediaId() async throws {
        // Create: draw into a fresh editor.
        let context = try makeContext()
        let editor = EditorViewModel(mode: .new)
        editor.name = "Star"
        editor.activeColor = .black
        editor.draw(x: 2, y: 3, beginningStroke: true)
        editor.draw(x: 4, y: 5, beginningStroke: true)

        // Save: the drawing persists, with the drawn pixels and nothing uploaded yet.
        let saved = editor.save(into: context)
        #expect(try context.fetch(FetchDescriptor<PixelArt>()).count == 1)
        #expect(saved.name == "Star")
        #expect(saved.grid.color(x: 2, y: 3) == .black)
        #expect(saved.grid.color(x: 4, y: 5) == .black)
        #expect(saved.lastUploadedMediaId == nil)

        // Assign (mocked): wire the detail view model exactly as the navigator does.
        let api = MockYotoAPI()
        api.cardsByID = ["CARD1": Fixtures.card()]
        api.uploadMediaId = "MEDIA-NEW"
        let vm = CardDetailViewModel(
            api: api,
            cardId: "CARD1",
            grid: saved.grid,
            artName: saved.name,
            cachedMediaId: saved.lastUploadedMediaId,
            onAssigned: { saved.lastUploadedMediaId = $0 })

        await vm.load()
        let track = try #require(vm.card?.chapters.first?.tracks.last) // "The Stars", no icon yet
        #expect(track.hasCustomIcon == false)
        await vm.assign(track: track)

        // The happy path end-to-end: one non-converting upload, the target track now
        // points at it, a success banner, and the media id cached back onto the art.
        #expect(api.uploads.count == 1)
        #expect(api.uploads.first?.autoConvert == false)
        let updated = try #require(api.updatedCards.last)
        #expect(updated.chapters.first?.tracks.last?.iconRef == "yoto:#MEDIA-NEW")
        #expect(vm.banner?.isError == false)

        // The refreshed card marks the track as showing the art in hand, and the
        // write-back closure the navigator depends on cached the media id.
        let assignedTrack = try #require(vm.card?.chapters.first?.tracks.last)
        #expect(vm.showsCurrentArt(assignedTrack))
        #expect(saved.lastUploadedMediaId == "MEDIA-NEW")
    }

    @Test func assignOneSavedArtToTwoTracksUploadsOnce() async throws {
        // Create + save a drawing, then assign it to two tracks of the same card.
        let context = try makeContext()
        let editor = EditorViewModel(mode: .new)
        editor.name = "Moon"
        editor.draw(x: 0, y: 0, beginningStroke: true)
        let saved = editor.save(into: context)

        let api = MockYotoAPI()
        api.cardsByID = ["CARD1": Fixtures.card()]
        api.uploadMediaId = "MEDIA-ONE"
        let vm = CardDetailViewModel(
            api: api,
            cardId: "CARD1",
            grid: saved.grid,
            artName: saved.name,
            cachedMediaId: saved.lastUploadedMediaId,
            onAssigned: { saved.lastUploadedMediaId = $0 })

        await vm.load()
        let tracks = try #require(vm.card?.chapters.first?.tracks)
        await vm.assign(track: tracks[0])
        await vm.assign(track: tracks[1])

        // The first assign uploads; the second reuses that upload for the same art,
        // so both tracks end up pointing at the one media id.
        #expect(api.uploads.count == 1)
        let updated = try #require(api.updatedCards.last)
        #expect(updated.chapters.first?.tracks[0].iconRef == "yoto:#MEDIA-ONE")
        #expect(updated.chapters.first?.tracks[1].iconRef == "yoto:#MEDIA-ONE")
        #expect(saved.lastUploadedMediaId == "MEDIA-ONE")
        #expect(vm.banner?.isError == false)
    }
}
