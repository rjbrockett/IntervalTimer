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
        
        // First attempt
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        
        // Delete existing store and retry (handles schema changes during development)
        let storeURL = configuration.url
        for ext in ["", ".shm", ".wal"] {
            if ext.isEmpty {
                try? FileManager.default.removeItem(at: storeURL)
            } else {
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension(ext))
            }
        }
        // Also try the -shm/-wal variants
        let base = storeURL.deletingPathExtension()
        for suffix in ["store-shm", "store-wal"] {
            try? FileManager.default.removeItem(at: base.appendingPathExtension(suffix))
        }
        UserDefaults.standard.removeObject(forKey: "hasSeededSampleData")
        
        return try? ModelContainer(for: schema, configurations: [configuration])
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
