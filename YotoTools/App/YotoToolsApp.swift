import SwiftData
import SwiftUI

@main
struct YotoToolsApp: App {
    @State private var appEnvironment = AppEnvironment()
    private let modelContainer = YotoToolsApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ToolsHomeView()
                .environment(appEnvironment)
                .task { await appEnvironment.bootstrap() }
        }
        .modelContainer(modelContainer)
    }

    /// SwiftData container backed by CloudKit, falling back to a local-only store
    /// when CloudKit isn't available (e.g. no signed-in iCloud account).
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([PixelArt.self])
        do {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            // If even the local store fails, there's nothing usable to fall back to.
            return try! ModelContainer(for: schema, configurations: configuration)
        }
    }
}
