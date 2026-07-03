import SwiftData
import SwiftUI

/// Grid of saved pixel art with a button to create a new one.
struct PixelArtGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PixelArt.modifiedAt, order: .reverse) private var artworks: [PixelArt]
    @State private var galleryModel = GalleryViewModel()

    let onNew: () -> Void
    let onOpen: (PixelArt) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        Group {
            if artworks.isEmpty {
                ContentUnavailableView {
                    Label("No Pixel Art Yet", systemImage: "paintpalette")
                } description: {
                    Text("Create your first 16×16 icon to assign to a Yoto track.")
                } actions: {
                    Button("Create Pixel Art", action: onNew)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(artworks) { art in
                            cell(for: art)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Pixel Art")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNew) {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private func cell(for art: PixelArt) -> some View {
        Button {
            onOpen(art)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                PixelThumbnail(grid: art.grid)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                Text(art.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(art.modifiedAt, format: .dateTime.month().day().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                galleryModel.duplicate(art, in: modelContext)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                galleryModel.delete(art, in: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
