import Foundation
import SwiftData

/// All editor logic, independent of any view, so it can be unit-tested directly.
@MainActor
@Observable
final class EditorViewModel {
    enum Mode {
        case new
        case existing(PixelArt)
    }

    var name: String
    private(set) var grid: PixelGrid
    var activeTool: DrawingTool = .pencil
    var activeColor: PixelColor = .black
    var showsGrid: Bool = true

    private let mode: Mode
    private let dateProvider: DateProvider
    private var baselineGrid: PixelGrid
    private var baselineName: String
    private var undoStack: [PixelGrid] = []
    private var redoStack: [PixelGrid] = []
    private let maxUndoSteps = 50

    init(mode: Mode, dateProvider: DateProvider = .live) {
        self.mode = mode
        self.dateProvider = dateProvider
        switch mode {
        case .new:
            let grid = PixelGrid()
            self.grid = grid
            self.baselineGrid = grid
            self.name = "Untitled"
            self.baselineName = "Untitled"
        case .existing(let art):
            let grid = art.grid
            self.grid = grid
            self.baselineGrid = grid
            self.name = art.name
            self.baselineName = art.name
        }
    }

    // MARK: Derived state

    var isExistingArt: Bool {
        if case .existing = mode { return true }
        return false
    }

    var isDirty: Bool {
        grid != baselineGrid || trimmedName != baselineName
    }

    /// True when saving should ask whether to overwrite or save a copy.
    var requiresSaveChoice: Bool {
        isExistingArt && isDirty
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isCanvasEmpty: Bool { grid.isEmpty }

    var trimmedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    // MARK: Drawing

    /// Applies the active tool at a cell. Pass `beginningStroke` true for the first
    /// touch of a drag (or a discrete tap) so a single undo step covers the stroke.
    func draw(x: Int, y: Int, beginningStroke: Bool) {
        guard grid.isInBounds(x: x, y: y) else { return }

        if activeTool == .eyedropper {
            let sampled = grid.color(x: x, y: y)
            if !sampled.isClear { activeColor = sampled }
            return
        }

        if beginningStroke { pushUndoSnapshot() }

        switch activeTool {
        case .pencil:
            grid.setColor(activeColor, x: x, y: y)
        case .eraser:
            grid.setColor(.clear, x: x, y: y)
        case .fill:
            grid.floodFill(x: x, y: y, with: activeColor)
        case .eyedropper:
            break
        }
    }

    func clearCanvas() {
        guard !grid.isEmpty else { return }
        pushUndoSnapshot()
        grid = PixelGrid()
    }

    /// Replaces the grid wholesale (e.g. after importing a photo) as one undo step.
    func replaceGrid(_ newGrid: PixelGrid) {
        guard newGrid != grid else { return }
        pushUndoSnapshot()
        grid = newGrid
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(grid)
        grid = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(grid)
        grid = next
    }

    private func pushUndoSnapshot() {
        undoStack.append(grid)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    // MARK: Saving

    /// Persists according to mode. For `.new`, inserts a record. For unmodified
    /// existing art, returns it unchanged. For modified existing art the caller
    /// should consult `requiresSaveChoice` first and call `overwrite`/`saveAsNew`.
    @discardableResult
    func save(into context: ModelContext) -> PixelArt {
        switch mode {
        case .new:
            return saveAsNew(into: context)
        case .existing(let art):
            return isDirty ? overwrite(art, into: context) : art
        }
    }

    @discardableResult
    func saveAsNew(into context: ModelContext) -> PixelArt {
        let now = dateProvider.now()
        let art = PixelArt(name: trimmedName, grid: grid, createdAt: now, modifiedAt: now)
        context.insert(art)
        try? context.save()
        commitBaseline()
        return art
    }

    @discardableResult
    func overwriteExisting(into context: ModelContext) -> PixelArt? {
        guard case .existing(let art) = mode else { return nil }
        return overwrite(art, into: context)
    }

    private func overwrite(_ art: PixelArt, into context: ModelContext) -> PixelArt {
        art.name = trimmedName
        art.grid = grid
        art.modifiedAt = dateProvider.now()
        // The art may have diverged from its last upload.
        art.lastUploadedMediaId = nil
        try? context.save()
        commitBaseline()
        return art
    }

    private func commitBaseline() {
        baselineGrid = grid
        baselineName = trimmedName
        name = trimmedName
    }
}
