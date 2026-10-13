import Foundation
import SwiftData

// MARK: - Schema V1
// Snapshot of the current model schema. When adding new fields or changing
// existing models in the future, create a new VersionedSchema (V2, V3, etc.)
// and add a migration stage.
//
// NOTE: The migration plan is NOT wired into ModelContainer until V2 is created.
// Adding it with only V1 causes a runtime crash with CloudKit-backed stores.
// When V2 is ready, add `migrationPlan: IntervalTimerMigrationPlan.self` to
// the ModelContainer initializer in both IntervalTimerApp and IntervalTimerWatchApp.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self
        ]
    }
}

// MARK: - Migration Plan

enum IntervalTimerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the initial schema.
        // When adding V2, add a migration stage here:
        //
        // static let migrateV1toV2 = MigrationStage.lightweight(
        //     fromVersion: SchemaV1.self,
        //     toVersion: SchemaV2.self
        // )
        []
    }
}
