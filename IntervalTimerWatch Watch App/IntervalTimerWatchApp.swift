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
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
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
