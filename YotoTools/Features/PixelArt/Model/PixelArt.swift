import Foundation
import SwiftData

/// A saved pixel-art drawing. CloudKit-compatible: every stored property has a
/// default value or is optional, and there are no unique constraints.
@Model
final class PixelArt {
    var name: String = "Untitled"
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    /// Raw 1024-byte RGBA encoding of a 16×16 `PixelGrid`.
    var pixelData: Data = Data(count: PixelGrid.byteCount)
    /// Cached media id of the most recent successful upload, to avoid re-uploading
    /// unchanged art.
    var lastUploadedMediaId: String?

    init(
        name: String = "Untitled",
        grid: PixelGrid = PixelGrid(),
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.name = name
        self.pixelData = grid.encoded()
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// The decoded grid (falls back to an empty grid if data is somehow malformed).
    var grid: PixelGrid {
        get { PixelGrid(data: pixelData) ?? PixelGrid() }
        set { pixelData = newValue.encoded() }
    }
}
