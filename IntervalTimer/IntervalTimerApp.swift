import SwiftUI
import SwiftData

@main
struct IntervalTimerApp: App {
    let modelContainer: ModelContainer
    @State private var pendingImportRecordName: String?

    init() {
        let schema = Schema([
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self
        ])
        
        // Try CloudKit first, fall back to local-only if it fails
        // (e.g., simulator without iCloud sign-in, schema mismatch)
        if let container = Self.createContainer(schema: schema, cloudKit: true) {
            modelContainer = container
        } else if let container = Self.createContainer(schema: schema, cloudKit: false) {
            print("⚠️ CloudKit unavailable — using local storage. Sign into iCloud for sync.")
            modelContainer = container
        } else {
            fatalError("Failed to create ModelContainer with both CloudKit and local storage")
        }
    }
    
    private static func createContainer(schema: Schema, cloudKit: Bool) -> ModelContainer? {
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(pendingImportRecordName: $pendingImportRecordName)
                .onOpenURL { url in
                    if let recordName = CloudKitSharingService.parseShareURL(url) {
                        pendingImportRecordName = recordName
                    }
                }
        }
        .modelContainer(modelContainer)
        
        #if os(macOS)
        Settings {
            Text("IntervalTimer Settings")
                .frame(width: 400, height: 300)
        }
        #endif
    }
}
