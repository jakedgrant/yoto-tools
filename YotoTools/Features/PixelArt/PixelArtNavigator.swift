import SwiftData
import SwiftUI

/// Value-based routes for the Pixel Art tool. Carrying `PersistentIdentifier`
/// keeps routes `Hashable`/`Codable` and works identically on iPhone and iPad.
enum PixelArtRoute: Hashable {
    case editor(PersistentIdentifier?)
    case assignCards(PersistentIdentifier)
    case assignDetail(art: PersistentIdentifier, cardId: String)
}

/// Owns the navigation stack for the Pixel Art tool and resolves models for routes.
struct PixelArtNavigator: View {
    @Environment(\.modelContext) private var modelContext
    @State private var path: [PixelArtRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            PixelArtGalleryView(
                onNew: { path.append(.editor(nil)) },
                onOpen: { art in path.append(.editor(art.persistentModelID)) })
                .navigationDestination(for: PixelArtRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: PixelArtRoute) -> some View {
        switch route {
        case .editor(let id):
            let art = id.flatMap { modelContext.model(for: $0) as? PixelArt }
            PixelArtEditorView(
                mode: art.map { .existing($0) } ?? .new,
                onAssign: { saved in path.append(.assignCards(saved.persistentModelID)) })

        case .assignCards(let id):
            if let art = modelContext.model(for: id) as? PixelArt {
                CardListView(
                    art: art,
                    onSelectCard: { cardId in
                        path.append(.assignDetail(art: id, cardId: cardId))
                    })
            } else {
                missingArt
            }

        case .assignDetail(let id, let cardId):
            if let art = modelContext.model(for: id) as? PixelArt {
                CardDetailView(art: art, cardId: cardId, onFinished: { path.removeAll() })
            } else {
                missingArt
            }
        }
    }

    private var missingArt: some View {
        ContentUnavailableView("Artwork Unavailable", systemImage: "exclamationmark.triangle")
    }
}
