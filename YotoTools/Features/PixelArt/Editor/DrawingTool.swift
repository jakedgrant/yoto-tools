import Foundation

enum DrawingTool: String, CaseIterable, Identifiable, Sendable {
    case pencil
    case eraser
    case fill
    case eyedropper
    case line
    case rectangle
    case ellipse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pencil: "Pencil"
        case .eraser: "Eraser"
        case .fill: "Fill"
        case .eyedropper: "Eyedropper"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    var systemImage: String {
        switch self {
        case .pencil: "pencil.tip"
        case .eraser: "eraser"
        case .fill: "drop.fill"
        case .eyedropper: "eyedropper"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "oval"
        }
    }

    /// Shape tools drag out a preview and commit on release instead of painting cells.
    var isShape: Bool {
        switch self {
        case .line, .rectangle, .ellipse: true
        case .pencil, .eraser, .fill, .eyedropper: false
        }
    }
}

/// Symmetry applied while drawing: mirrored cells receive the same edit.
enum MirrorMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case horizontal
    case vertical
    case fourWay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Mirror Off"
        case .horizontal: "Mirror Left–Right"
        case .vertical: "Mirror Top–Bottom"
        case .fourWay: "Mirror 4-Way"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "square"
        case .horizontal: "rectangle.split.2x1"
        case .vertical: "rectangle.split.1x2"
        case .fourWay: "rectangle.split.2x2"
        }
    }

    /// The cell plus its mirrored counterparts across the canvas center lines.
    func expand(_ point: PixelGrid.Point) -> [PixelGrid.Point] {
        let mx = PixelGrid.side - 1 - point.x
        let my = PixelGrid.side - 1 - point.y
        switch self {
        case .off:
            return [point]
        case .horizontal:
            return [point, PixelGrid.Point(x: mx, y: point.y)]
        case .vertical:
            return [point, PixelGrid.Point(x: point.x, y: my)]
        case .fourWay:
            return [
                point,
                PixelGrid.Point(x: mx, y: point.y),
                PixelGrid.Point(x: point.x, y: my),
                PixelGrid.Point(x: mx, y: my),
            ]
        }
    }
}
