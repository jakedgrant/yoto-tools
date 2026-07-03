import Foundation

enum DrawingTool: String, CaseIterable, Identifiable, Sendable {
    case pencil
    case eraser
    case fill
    case eyedropper

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pencil: "Pencil"
        case .eraser: "Eraser"
        case .fill: "Fill"
        case .eyedropper: "Eyedropper"
        }
    }

    var systemImage: String {
        switch self {
        case .pencil: "pencil.tip"
        case .eraser: "eraser"
        case .fill: "drop.fill"
        case .eyedropper: "eyedropper"
        }
    }
}
