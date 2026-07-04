import SwiftUI

@MainActor
@Observable
final class IconBrowserViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var loadState: LoadState = .loading
    private(set) var userIcons: [DisplayIcon] = []
    private(set) var publicIcons: [DisplayIcon] = []
    var searchText = ""

    private let api: any YotoAPI

    init(api: any YotoAPI) {
        self.api = api
    }

    func load() async {
        loadState = .loading
        do {
            async let mine = api.getUserIcons()
            async let library = api.getPublicIcons()
            (userIcons, publicIcons) = try await (mine, library)
            loadState = .loaded
        } catch {
            loadState = .failed(APIErrorFormatter.message(error))
        }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Public icons matching the search text by title or tag (all when empty).
    var filteredPublicIcons: [DisplayIcon] {
        let query = trimmedQuery
        guard !query.isEmpty else { return publicIcons }
        return publicIcons.filter { icon in
            (icon.title?.localizedCaseInsensitiveContains(query) ?? false)
                || icon.publicTags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Uploads have no titles or tags to match, so hide them while searching.
    var showsUserIcons: Bool {
        trimmedQuery.isEmpty && !userIcons.isEmpty
    }
}

/// Browses the user's uploaded icons and Yoto's public icon library.
struct IconBrowserView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var viewModel: IconBrowserViewModel?

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Icon Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = IconBrowserViewModel(api: appEnvironment.api)
            viewModel = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: IconBrowserViewModel) -> some View {
        @Bindable var viewModel = viewModel
        switch viewModel.loadState {
        case .loading:
            ProgressView("Loading icons…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        case .loaded:
            iconGrids(viewModel)
                .searchable(text: $viewModel.searchText, prompt: "Search titles and tags")
        }
    }

    private func iconGrids(_ viewModel: IconBrowserViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if viewModel.showsUserIcons {
                    sectionHeader("My Uploads")
                    iconGrid(viewModel.userIcons)
                }
                sectionHeader("Yoto Library")
                if viewModel.filteredPublicIcons.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    iconGrid(viewModel.filteredPublicIcons)
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func iconGrid(_ icons: [DisplayIcon]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(icons) { icon in
                iconCell(icon)
            }
        }
    }

    private func iconCell(_ icon: DisplayIcon) -> some View {
        AsyncImage(url: icon.url) { image in
            image
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        .accessibilityLabel(icon.title ?? "Icon")
        .contextMenu {
            if let title = icon.title {
                Text(title)
            }
            if !icon.publicTags.isEmpty {
                Text(icon.publicTags.joined(separator: ", "))
            }
        }
    }
}
