import SwiftUI
import SwiftData

@main
struct IntervalTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
        
        #if os(macOS)
        Settings {
            Text("IntervalTimer Settings")
                .frame(width: 400, height: 300)
        }
        #endif
    }
}
