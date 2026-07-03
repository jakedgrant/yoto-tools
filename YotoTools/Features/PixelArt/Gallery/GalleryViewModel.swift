import Foundation
import SwiftData

/// Gallery actions (delete/duplicate/fetch). View listing uses `@Query`; this type
/// exists so the same logic is unit-testable against an in-memory store.
@MainActor
@Observable
final class GalleryViewModel {
    private let dateProvider: DateProvider

    init(dateProvider: DateProvider = .live) {
        self.dateProvider = dateProvider
    }

    func allArtwork(in context: ModelContext) -> [PixelArt] {
        let descriptor = FetchDescriptor<PixelArt>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func delete(_ art: PixelArt, in context: ModelContext) {
        context.delete(art)
        try? context.save()
    }

    @discardableResult
    func duplicate(_ art: PixelArt, in context: ModelContext) -> PixelArt {
        let now = dateProvider.now()
        let copy = PixelArt(
            name: "\(art.name) copy",
            grid: art.grid,
            createdAt: now,
            modifiedAt: now)
        context.insert(copy)
        try? context.save()
        return copy
    }
}
