import SwiftUI

@MainActor
@Observable
final class CardDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    struct Banner: Equatable {
        var message: String
        var isError: Bool
    }

    private(set) var loadState: LoadState = .loading
    private(set) var card: CardDetail?
    private(set) var assigningTrackID: String?
    private(set) var assigningChapterIndex: Int?
    var banner: Banner?

    /// Whether any assign/unassign operation is in flight.
    var isBusy: Bool { assigningTrackID != nil || assigningChapterIndex != nil }

    private let api: any YotoAPI
    private let assignment: IconAssignmentService
    private let cardId: String
    private let grid: PixelGrid
    private let artName: String
    /// Media id of this art's most recent upload, if any; assigning reuses it
    /// (when the server still has it) instead of uploading again.
    private var cachedMediaId: String?
    /// Called after a successful assign with the new media id (for local caching).
    private let onAssigned: (String) -> Void

    init(
        api: any YotoAPI,
        cardId: String,
        grid: PixelGrid,
        artName: String,
        cachedMediaId: String? = nil,
        onAssigned: @escaping (String) -> Void
    ) {
        self.api = api
        self.assignment = IconAssignmentService(api: api)
        self.cardId = cardId
        self.grid = grid
        self.artName = artName
        self.cachedMediaId = cachedMediaId
        self.onAssigned = onAssigned
    }

    func load() async {
        loadState = .loading
        do {
            card = try await api.getContent(cardId: cardId)
            loadState = .loaded
        } catch {
            loadState = .failed(APIErrorFormatter.message(error))
        }
    }

    func assign(track: TrackView) async {
        guard let currentCard = card, !isBusy else { return }
        assigningTrackID = track.id
        defer { assigningTrackID = nil }
        do {
            let result = try await assignment.assign(
                grid: grid,
                to: track,
                in: currentCard,
                filename: filename,
                cachedMediaId: cachedMediaId)
            card = result.card
            cachedMediaId = result.mediaId
            onAssigned(result.mediaId)
            banner = Banner(message: "Assigned to \"\(track.title)\".", isError: false)
        } catch {
            banner = Banner(message: APIErrorFormatter.message(error), isError: true)
        }
    }

    func assign(chapter: ChapterView) async {
        guard let currentCard = card, !isBusy, !chapter.tracks.isEmpty else { return }
        assigningChapterIndex = chapter.index
        defer { assigningChapterIndex = nil }
        do {
            let result = try await assignment.assign(
                grid: grid,
                toChapter: chapter,
                in: currentCard,
                filename: filename,
                cachedMediaId: cachedMediaId)
            card = result.card
            cachedMediaId = result.mediaId
            onAssigned(result.mediaId)
            banner = Banner(
                message: "Assigned to all \(chapter.tracks.count) tracks in \"\(chapter.title)\".",
                isError: false)
        } catch {
            banner = Banner(message: APIErrorFormatter.message(error), isError: true)
        }
    }

    func unassign(track: TrackView) async {
        guard let currentCard = card, !isBusy else { return }
        assigningTrackID = track.id
        defer { assigningTrackID = nil }
        do {
            card = try await assignment.unassign(track: track, in: currentCard)
            banner = Banner(message: "Removed icon from \"\(track.title)\".", isError: false)
        } catch {
            banner = Banner(message: APIErrorFormatter.message(error), isError: true)
        }
    }

    /// Whether `track` currently shows the art being assigned (by media id).
    func showsCurrentArt(_ track: TrackView) -> Bool {
        guard let cachedMediaId else { return false }
        return track.iconRef == "yoto:#\(cachedMediaId)"
    }

    private var filename: String {
        let safe = artName.replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
        return safe.isEmpty ? "icon" : safe
    }
}

/// Shows a card's chapters and tracks; tapping a track uploads the art and assigns it.
struct CardDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    let art: PixelArt
    let cardId: String
    let onFinished: () -> Void

    @State private var viewModel: CardDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Assign to Track")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: onFinished)
            }
        }
        .task {
            let model = CardDetailViewModel(
                api: appEnvironment.api,
                cardId: cardId,
                grid: art.grid,
                artName: art.name,
                cachedMediaId: art.lastUploadedMediaId,
                onAssigned: { mediaId in art.lastUploadedMediaId = mediaId })
            viewModel = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: CardDetailViewModel) -> some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView("Loading tracks…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        case .loaded:
            trackList(viewModel)
        }
    }

    private func trackList(_ viewModel: CardDetailViewModel) -> some View {
        List {
            artPreviewSection
            ForEach(viewModel.card?.chapters ?? []) { chapter in
                Section {
                    ForEach(chapter.tracks) { track in
                        trackRow(track, viewModel: viewModel)
                    }
                } header: {
                    chapterHeader(chapter, viewModel: viewModel)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let banner = viewModel.banner {
                bannerView(banner)
            }
        }
    }

    private var artPreviewSection: some View {
        Section {
            HStack(spacing: 12) {
                PixelThumbnail(grid: art.grid)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text(art.name).font(.headline)
                    Text("Tap a track to assign this icon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chapterHeader(_ chapter: ChapterView, viewModel: CardDetailViewModel) -> some View {
        HStack {
            Text(chapter.title)
            Spacer()
            if viewModel.assigningChapterIndex == chapter.index {
                ProgressView()
                    .controlSize(.small)
            } else if chapter.tracks.count > 1 {
                Button("Assign All") {
                    Task { await viewModel.assign(chapter: chapter) }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.borderless)
                .disabled(viewModel.isBusy)
            }
        }
    }

    private func trackRow(_ track: TrackView, viewModel: CardDetailViewModel) -> some View {
        Button {
            Task { await viewModel.assign(track: track) }
        } label: {
            HStack(spacing: 12) {
                trackIcon(track)
                Text(track.title)
                Spacer()
                if viewModel.assigningTrackID == track.id {
                    ProgressView()
                } else if viewModel.showsCurrentArt(track) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Shows this icon")
                } else if track.hasCustomIcon {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
        .swipeActions(edge: .trailing) {
            removeIconButton(track, viewModel: viewModel)
        }
        .contextMenu {
            removeIconButton(track, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func removeIconButton(_ track: TrackView, viewModel: CardDetailViewModel) -> some View {
        if track.hasCustomIcon {
            Button("Remove Icon", systemImage: "xmark.circle", role: .destructive) {
                Task { await viewModel.unassign(track: track) }
            }
        }
    }

    private func trackIcon(_ track: TrackView) -> some View {
        AsyncImage(url: track.iconURL) { image in
            image.resizable().interpolation(.none).scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func bannerView(_ banner: CardDetailViewModel.Banner) -> some View {
        Text(banner.message)
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(banner.isError ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
            .foregroundStyle(banner.isError ? Color.red : Color.green)
    }
}
