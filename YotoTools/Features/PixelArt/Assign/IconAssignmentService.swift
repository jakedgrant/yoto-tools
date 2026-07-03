import Foundation

enum AssignError: Error, Equatable {
    case pngEncodingFailed
}

/// Orchestrates uploading a pixel grid and pointing a specific track at it.
/// SwiftData-free so the core logic is unit-testable with a mocked API.
struct IconAssignmentService: Sendable {
    let api: any YotoAPI

    /// Uploads `grid` as a PNG, sets the track's `display.icon16x16`, persists the
    /// mutated card, and returns the saved card plus the new media id.
    func assign(
        grid: PixelGrid,
        to track: TrackView,
        in card: CardDetail,
        filename: String,
        autoConvert: Bool = false
    ) async throws -> (card: CardDetail, mediaId: String) {
        guard let png = grid.pngData() else { throw AssignError.pngEncodingFailed }
        let mediaId = try await api.uploadIcon(
            pngData: png,
            filename: filename,
            autoConvert: autoConvert)
        var updated = card
        updated.setTrackIcon(
            chapterIndex: track.chapterIndex,
            trackIndex: track.trackIndex,
            mediaId: mediaId)
        let saved = try await api.updateContent(updated)
        return (saved, mediaId)
    }
}
