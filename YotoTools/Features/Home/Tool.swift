import Foundation

/// A utility hosted by the app. Designed to grow as more Yoto tools are added.
enum Tool: String, CaseIterable, Identifiable, Hashable {
    case pixelArt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixelArt: "Pixel Art"
        }
    }

    var subtitle: String {
        switch self {
        case .pixelArt: "Draw 16×16 icons for your tracks"
        }
    }

    var systemImage: String {
        switch self {
        case .pixelArt: "paintpalette"
        }
    }
}
