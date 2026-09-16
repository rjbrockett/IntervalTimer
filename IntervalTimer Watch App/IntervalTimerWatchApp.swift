import SwiftUI
import SwiftData

@main
struct IntervalTimer_Watch_App: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
    }
}
