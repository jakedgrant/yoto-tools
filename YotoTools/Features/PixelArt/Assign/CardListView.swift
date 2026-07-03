import SwiftUI

@MainActor
@Observable
final class CardListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([CardSummary])
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private let api: any YotoAPI

    init(api: any YotoAPI) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            let cards = try await api.getMyContent()
            state = .loaded(cards)
        } catch {
            state = .failed(APIErrorFormatter.message(error))
        }
    }
}

/// Lists the user's playlists/cards so one can be opened to pick a track.
struct CardListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    let art: PixelArt
    let onSelectCard: (String) -> Void

    @State private var viewModel: CardListViewModel?

    var body: some View {
        Group {
            if !appEnvironment.auth.isSignedIn {
                signInPrompt
            } else if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Choose a Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: appEnvironment.auth.isSignedIn) {
            guard appEnvironment.auth.isSignedIn else { return }
            let model = CardListViewModel(api: appEnvironment.api)
            viewModel = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: CardListViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading your content…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        case .loaded(let cards):
            if cards.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "tray",
                    description: Text("You don't have any 'Make Your Own' content yet."))
            } else {
                List(cards) { card in
                    Button {
                        onSelectCard(card.id)
                    } label: {
                        HStack(spacing: 12) {
                            cover(for: card)
                            Text(card.title)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cover(for card: CardSummary) -> some View {
        AsyncImage(url: card.coverImageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.secondary.opacity(0.15)
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var signInPrompt: some View {
        ContentUnavailableView {
            Label("Sign In Required", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("Sign in to your Yoto account in Settings to assign icons to your tracks.")
        }
    }
}
