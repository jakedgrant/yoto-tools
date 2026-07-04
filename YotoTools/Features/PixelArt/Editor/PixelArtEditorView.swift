import PhotosUI
import SwiftData
import SwiftUI

/// The drawing screen. Thin: all behavior is delegated to `EditorViewModel`.
struct PixelArtEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: EditorViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var customColor: Color = .blue
    @State private var saveIntent: SaveIntent?
    @State private var photoError: String?

    /// Called once a saved `PixelArt` is ready to be assigned to a track.
    let onAssign: (PixelArt) -> Void

    private enum SaveIntent {
        case finish
        case assign
    }

    init(mode: EditorViewModel.Mode, onAssign: @escaping (PixelArt) -> Void) {
        _viewModel = State(initialValue: EditorViewModel(mode: mode))
        self.onAssign = onAssign
    }

    var body: some View {
        VStack(spacing: 16) {
            PixelCanvasView(
                grid: viewModel.displayGrid,
                showsGrid: viewModel.showsGrid,
                onDraw: { x, y, beginning in
                    viewModel.draw(x: x, y: y, beginningStroke: beginning)
                },
                onStrokeEnded: { viewModel.endStroke() })
                .padding(.horizontal)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            toolStrip
            ColorPaletteView(activeColor: $viewModel.activeColor, customColor: $customColor)
            Spacer(minLength: 0)
        }
        .padding(.vertical)
        .navigationTitle(viewModel.trimmedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .photosPickerStyle(.presentation)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPhoto(newItem) }
        }
        .confirmationDialog(
            "Save changes",
            isPresented: saveDialogBinding,
            titleVisibility: .visible) {
                Button("Overwrite Original") { completeSave(overwrite: true) }
                Button("Save as New Copy") { completeSave(overwrite: false) }
                Button("Cancel", role: .cancel) { saveIntent = nil }
        } message: {
            Text("You've edited \"\(viewModel.trimmedName)\". Overwrite the original or keep it and save a new copy?")
        }
        .alert("Couldn't import photo", isPresented: photoErrorBinding) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "")
        }
    }

    // MARK: Tool strip

    private var toolStrip: some View {
        VStack(spacing: 12) {
            Picker("Tool", selection: $viewModel.activeTool) {
                ForEach(DrawingTool.allCases) { tool in
                    // Icon-only segments: seven text labels don't fit an iPhone width.
                    Image(systemName: tool.systemImage)
                        .accessibilityLabel(tool.label)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 18) {
                Button { viewModel.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)

                Button { viewModel.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)

                Button { viewModel.clearCanvas() } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.isCanvasEmpty)

                Toggle(isOn: $viewModel.showsGrid) {
                    Image(systemName: "grid")
                }
                .toggleStyle(.button)

                Menu {
                    Picker("Mirror", selection: $viewModel.mirrorMode) {
                        ForEach(MirrorMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.mirrorMode == .off
                        ? "rectangle.split.2x1"
                        : viewModel.mirrorMode.systemImage)
                        .foregroundStyle(viewModel.mirrorMode == .off ? Color.secondary : Color.accentColor)
                }
                .accessibilityLabel(viewModel.mirrorMode.label)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
            }
            .font(.title3)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TextField("Name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let exportable = exportablePNG {
                ShareLink(item: exportable, preview: SharePreview(viewModel.trimmedName)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            Menu {
                Button { requestSave(intent: .finish) } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                Button { requestSave(intent: .assign) } label: {
                    Label("Save & Assign to Track…", systemImage: "rectangle.stack.badge.person.crop")
                }
            } label: {
                Text("Save").fontWeight(.semibold)
            }
        }
    }

    // MARK: Actions

    private var exportablePNG: ExportablePNG? {
        guard let data = viewModel.grid.pngData() else { return nil }
        return ExportablePNG(data: data, name: viewModel.trimmedName)
    }

    private func requestSave(intent: SaveIntent) {
        if viewModel.requiresSaveChoice {
            saveIntent = intent
        } else {
            let art = viewModel.save(into: modelContext)
            finish(intent: intent, art: art)
        }
    }

    private func completeSave(overwrite: Bool) {
        let intent = saveIntent ?? .finish
        let art = overwrite
            ? (viewModel.overwriteExisting(into: modelContext) ?? viewModel.saveAsNew(into: modelContext))
            : viewModel.saveAsNew(into: modelContext)
        saveIntent = nil
        finish(intent: intent, art: art)
    }

    private func finish(intent: SaveIntent, art: PixelArt) {
        switch intent {
        case .finish:
            dismiss()
        case .assign:
            onAssign(art)
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                photoError = "That image couldn't be read."
                return
            }
            viewModel.replaceGrid(PixelGrid(downscaling: cgImage))
        } catch {
            photoError = error.localizedDescription
        }
    }

    private var saveDialogBinding: Binding<Bool> {
        Binding(get: { saveIntent != nil }, set: { if !$0 { saveIntent = nil } })
    }

    private var photoErrorBinding: Binding<Bool> {
        Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })
    }
}
