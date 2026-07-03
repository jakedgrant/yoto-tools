import Foundation
import SwiftData
import Testing
@testable import YotoTools

@MainActor
struct GalleryViewModelTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PixelArt.self, configurations: configuration)
        return ModelContext(container)
    }

    @Test func listsArtworkNewestFirst() throws {
        let context = try makeContext()
        context.insert(PixelArt(name: "Old", modifiedAt: Date(timeIntervalSince1970: 100)))
        context.insert(PixelArt(name: "New", modifiedAt: Date(timeIntervalSince1970: 900)))
        context.insert(PixelArt(name: "Mid", modifiedAt: Date(timeIntervalSince1970: 500)))

        let vm = GalleryViewModel()
        let names = vm.allArtwork(in: context).map(\.name)
        #expect(names == ["New", "Mid", "Old"])
    }

    @Test func deleteRemovesArtwork() throws {
        let context = try makeContext()
        let art = PixelArt(name: "Trash me")
        context.insert(art)

        let vm = GalleryViewModel()
        vm.delete(art, in: context)
        #expect(vm.allArtwork(in: context).isEmpty)
    }

    @Test func duplicateCreatesCopyWithSuffix() throws {
        let context = try makeContext()
        var grid = PixelGrid()
        grid.setColor(.black, x: 1, y: 1)
        let art = PixelArt(name: "Heart", grid: grid)
        context.insert(art)

        let fixed = Date(timeIntervalSince1970: 4242)
        let vm = GalleryViewModel(dateProvider: .fixed(fixed))
        let copy = vm.duplicate(art, in: context)

        #expect(copy.name == "Heart copy")
        #expect(copy.createdAt == fixed)
        #expect(copy.grid.color(x: 1, y: 1) == .black)
        #expect(vm.allArtwork(in: context).count == 2)
    }
}
