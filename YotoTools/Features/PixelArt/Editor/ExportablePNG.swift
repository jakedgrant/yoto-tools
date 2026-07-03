import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A PNG payload that the share sheet can export as a `.png` file.
struct ExportablePNG: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { "\($0.name).png" }
    }
}
