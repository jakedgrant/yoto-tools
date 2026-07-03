import SwiftUI

/// Root of the app. A `NavigationSplitView` sidebar lists tools; the detail column
/// hosts the selected tool's own navigation stack. Collapses to a stack on iPhone.
struct ToolsHomeView: View {
    @State private var selection: Tool? = .pixelArt
    @State private var showsSettings = false

    var body: some View {
        NavigationSplitView {
            List(Tool.allCases, selection: $selection) { tool in
                Label {
                    VStack(alignment: .leading) {
                        Text(tool.title)
                        Text(tool.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: tool.systemImage)
                }
                .tag(tool)
            }
            .navigationTitle("Yoto Tools")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        } detail: {
            switch selection {
            case .pixelArt:
                PixelArtNavigator()
            case nil:
                ContentUnavailableView("Select a tool", systemImage: "square.grid.2x2")
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
