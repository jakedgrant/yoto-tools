import Foundation
import SwiftData
import Testing
@testable import YotoTools

@MainActor
struct EditorViewModelTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PixelArt.self, configurations: configuration)
        return ModelContext(container)
    }

    private let fixedDate = Date(timeIntervalSince1970: 5000)

    @Test func pencilDrawsAndMarksDirty() {
        let vm = EditorViewModel(mode: .new)
        vm.activeColor = .black
        vm.draw(x: 2, y: 3, beginningStroke: true)
        #expect(vm.grid.color(x: 2, y: 3) == .black)
        #expect(vm.isDirty)
    }

    @Test func eraserClearsPixel() {
        let vm = EditorViewModel(mode: .new)
        vm.draw(x: 1, y: 1, beginningStroke: true)
        vm.activeTool = .eraser
        vm.draw(x: 1, y: 1, beginningStroke: true)
        #expect(vm.grid.color(x: 1, y: 1).isClear)
    }

    @Test func eyedropperPicksColorWithoutMutatingGrid() {
        let vm = EditorViewModel(mode: .new)
        let teal = PixelColor(r: 0, g: 158, b: 170)
        vm.activeColor = teal
        vm.draw(x: 4, y: 4, beginningStroke: true)
        vm.activeColor = .white
        vm.activeTool = .eyedropper

        let before = vm.grid
        vm.draw(x: 4, y: 4, beginningStroke: true)
        #expect(vm.activeColor == teal)
        #expect(vm.grid == before)
    }

    @Test func fillFloodsCanvas() {
        let vm = EditorViewModel(mode: .new)
        vm.activeTool = .fill
        vm.activeColor = .white
        vm.draw(x: 0, y: 0, beginningStroke: true)
        #expect(vm.grid.color(x: 10, y: 10) == .white)
    }

    @Test func undoAndRedoRestoreSnapshots() {
        let vm = EditorViewModel(mode: .new)
        vm.draw(x: 0, y: 0, beginningStroke: true)
        #expect(vm.canUndo)

        vm.undo()
        #expect(vm.grid.color(x: 0, y: 0).isClear)
        #expect(vm.canRedo)

        vm.redo()
        #expect(vm.grid.color(x: 0, y: 0) == .black)
    }

    @Test func newArtworkSavesWithoutAChoice() throws {
        let context = try makeContext()
        let vm = EditorViewModel(mode: .new, dateProvider: .fixed(fixedDate))
        vm.name = "Star"
        vm.draw(x: 0, y: 0, beginningStroke: true)

        #expect(!vm.requiresSaveChoice)
        let saved = vm.save(into: context)
        #expect(saved.name == "Star")
        #expect(saved.createdAt == fixedDate)

        let all = try context.fetch(FetchDescriptor<PixelArt>())
        #expect(all.count == 1)
    }

    @Test func editingExistingArtworkRequiresChoice() throws {
        let context = try makeContext()
        let original = PixelArt(name: "Moon", createdAt: fixedDate, modifiedAt: fixedDate)
        context.insert(original)

        let vm = EditorViewModel(mode: .existing(original), dateProvider: .fixed(fixedDate))
        #expect(!vm.requiresSaveChoice) // not dirty yet
        vm.draw(x: 5, y: 5, beginningStroke: true)
        #expect(vm.requiresSaveChoice)
    }

    @Test func overwriteUpdatesExistingRecord() throws {
        let context = try makeContext()
        let original = PixelArt(
            name: "Moon",
            createdAt: Date(timeIntervalSince1970: 0),
            modifiedAt: Date(timeIntervalSince1970: 0))
        context.insert(original)

        let later = Date(timeIntervalSince1970: 9000)
        let vm = EditorViewModel(mode: .existing(original), dateProvider: .fixed(later))
        vm.name = "Full Moon"
        vm.draw(x: 5, y: 5, beginningStroke: true)
        let result = vm.overwriteExisting(into: context)

        #expect(result === original)
        #expect(original.name == "Full Moon")
        #expect(original.modifiedAt == later)
        #expect(original.grid.color(x: 5, y: 5) == .black)
        #expect(try context.fetch(FetchDescriptor<PixelArt>()).count == 1)
    }

    @Test func saveAsNewKeepsOriginalAndInsertsCopy() throws {
        let context = try makeContext()
        let original = PixelArt(name: "Moon")
        context.insert(original)

        let vm = EditorViewModel(mode: .existing(original), dateProvider: .fixed(fixedDate))
        vm.name = "Moon Variant"
        vm.draw(x: 6, y: 6, beginningStroke: true)
        let copy = vm.saveAsNew(into: context)

        #expect(copy !== original)
        #expect(original.name == "Moon")
        #expect(original.grid.color(x: 6, y: 6).isClear)
        #expect(try context.fetch(FetchDescriptor<PixelArt>()).count == 2)
    }
}
