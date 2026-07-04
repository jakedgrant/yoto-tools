import Foundation

enum AssignError: Error, Equatable {
    case pngEncodingFailed
}

/// Orchestrates uploading a pixel grid and pointing a specific track at it.
/// SwiftData-free so the core logic is unit-testable with a mocked API.
struct IconAssignmentService: Sendable {
    let api: any YotoAPI

    /// Uploads `grid` as a PNG — or reuses `cachedMediaId` when the server still
    /// has that upload — then sets the track's `display.icon16x16`, persists the
    /// mutated card, and returns the saved card plus the media id used.
    func assign(
        grid: PixelGrid,
        to track: TrackView,
        in card: CardDetail,
        filename: String,
        cachedMediaId: String? = nil,
        autoConvert: Bool = false
    ) async throws -> (card: CardDetail, mediaId: String) {
        let mediaId: String
        if let cachedMediaId, await serverHasIcon(mediaId: cachedMediaId) {
            mediaId = cachedMediaId
        } else {
            guard let png = grid.pngData() else { throw AssignError.pngEncodingFailed }
            mediaId = try await api.uploadIcon(
                pngData: png,
                filename: filename,
                autoConvert: autoConvert)
        }
        var updated = card
        updated.setTrackIcon(
            chapterIndex: track.chapterIndex,
            trackIndex: track.trackIndex,
            mediaId: mediaId)
        let saved = try await api.updateContent(updated)
        return (saved, mediaId)
    }

    /// Whether the server still lists an uploaded icon with `mediaId`. A failed
    /// lookup counts as "no", so assignment falls back to a fresh upload rather
    /// than failing on what is only an optimization.
    private func serverHasIcon(mediaId: String) async -> Bool {
        guard let icons = try? await api.getUserIcons() else { return false }
        return icons.contains { $0.mediaId == mediaId }
    }
}
