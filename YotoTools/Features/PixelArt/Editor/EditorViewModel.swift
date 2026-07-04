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
    var mirrorMode: MirrorMode = .off

    /// Live overlay while a shape tool is being dragged; committed by `endStroke()`.
    private(set) var shapePreview: PixelGrid?
    private var strokeStart: PixelGrid.Point?

    private let mode: Mode
    private let dateProvider: DateProvider
    private var baselineGrid: PixelGrid
    private var baselineName: String
    private var undoStack: [PixelGrid] = []
    private var redoStack: [PixelGrid] = []
    private let maxUndoSteps = 50

    /// What the canvas should render: the in-progress shape preview when present.
    var displayGrid: PixelGrid { shapePreview ?? grid }

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
        if activeTool.isShape {
            updateShapeStroke(x: x, y: y, beginningStroke: beginningStroke)
            return
        }

        guard grid.isInBounds(x: x, y: y) else { return }

        if activeTool == .eyedropper {
            let sampled = grid.color(x: x, y: y)
            if !sampled.isClear { activeColor = sampled }
            return
        }

        if beginningStroke { pushUndoSnapshot() }

        switch activeTool {
        case .pencil:
            write([PixelGrid.Point(x: x, y: y)], color: activeColor, into: &grid)
        case .eraser:
            write([PixelGrid.Point(x: x, y: y)], color: .clear, into: &grid)
        case .fill:
            for point in mirrorMode.expand(PixelGrid.Point(x: x, y: y)) {
                grid.floodFill(x: point.x, y: point.y, with: activeColor)
            }
        case .eyedropper, .line, .rectangle, .ellipse:
            break
        }
    }

    /// Finishes the current stroke; commits an in-progress shape as one undo step.
    func endStroke() {
        defer { strokeStart = nil }
        guard let preview = shapePreview else { return }
        shapePreview = nil
        guard preview != grid else { return }
        pushUndoSnapshot()
        grid = preview
    }

    private func updateShapeStroke(x: Int, y: Int, beginningStroke: Bool) {
        // Clamp so dragging past the edge keeps the shape pinned to the canvas.
        let point = PixelGrid.Point(
            x: min(max(x, 0), PixelGrid.side - 1),
            y: min(max(y, 0), PixelGrid.side - 1))
        if beginningStroke { strokeStart = point }
        guard let start = strokeStart else { return }

        var preview = grid
        write(shapePoints(from: start, to: point), color: activeColor, into: &preview)
        shapePreview = preview
    }

    private func shapePoints(from start: PixelGrid.Point, to end: PixelGrid.Point) -> [PixelGrid.Point] {
        switch activeTool {
        case .line: PixelGrid.linePoints(from: start, to: end)
        case .rectangle: PixelGrid.rectanglePoints(from: start, to: end)
        case .ellipse: PixelGrid.ellipsePoints(from: start, to: end)
        case .pencil, .eraser, .fill, .eyedropper: []
        }
    }

    /// The single write chokepoint: expands each cell through the mirror mode and
    /// clips to bounds.
    private func write(_ points: [PixelGrid.Point], color: PixelColor, into target: inout PixelGrid) {
        for point in points {
            for mirrored in mirrorMode.expand(point) where target.isInBounds(x: mirrored.x, y: mirrored.y) {
                target.setColor(color, x: mirrored.x, y: mirrored.y)
            }
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
            saveAsNew(into: context)
        case .existing(let art):
            isDirty ? overwrite(art, into: context) : art
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
