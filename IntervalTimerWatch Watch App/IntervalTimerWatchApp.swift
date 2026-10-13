import SwiftUI
import SwiftData

@main
struct IntervalTimer_Watch_App: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self
        ])
        
        #if targetEnvironment(simulator)
        // Simulator: local-only store (CloudKit entitlements unavailable)
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        #else
        // Device: CloudKit-backed store for cross-device sync
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        #endif
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(modelContainer)
    }
}
