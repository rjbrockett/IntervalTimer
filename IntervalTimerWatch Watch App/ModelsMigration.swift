import Foundation
import SwiftData

// MARK: - Schema V1
// Frozen snapshot of the original schema (non-CloudKit-compatible). Do not edit —
// it must match existing on-disk stores exactly so they can be migrated.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self
        ]
    }

    @Model
    final class WorkoutTemplate {
        var id: UUID
        var name: String
        var sortOrder: Int
        var showHeartRateZones: Bool
        var createdAt: Date?
        var updatedAt: Date?
        @Relationship(deleteRule: .cascade)
        var blocks: [IntervalBlock]
        var isDownloaded: Bool?
        var sourceRecordName: String?
        var sourceUpdatedAt: Date?
        var originalTemplateID: UUID?
        var isPublished: Bool?
        var publishedRecordName: String?
        var creatorName: String?
        var hasAvailableUpdate: Bool?

        init(id: UUID, name: String, sortOrder: Int, showHeartRateZones: Bool, blocks: [IntervalBlock]) {
            self.id = id
            self.name = name
            self.sortOrder = sortOrder
            self.showHeartRateZones = showHeartRateZones
            self.blocks = blocks
        }
    }

    @Model
    final class IntervalBlock {
        var id: UUID
        var name: String?
        var repeatCount: Int
        var sortOrder: Int
        @Relationship(deleteRule: .cascade)
        var intervals: [IntervalItem]
        @Relationship(deleteRule: .cascade, inverse: \IntervalBlock.parentBlock)
        var childBlocks: [IntervalBlock]
        var parentBlock: IntervalBlock?

        init(id: UUID, repeatCount: Int, sortOrder: Int, intervals: [IntervalItem], childBlocks: [IntervalBlock]) {
            self.id = id
            self.repeatCount = repeatCount
            self.sortOrder = sortOrder
            self.intervals = intervals
            self.childBlocks = childBlocks
        }
    }

    @Model
    final class IntervalItem {
        var id: UUID
        var name: String
        var duration: TimeInterval
        var sortOrder: Int
        var trackDistance: Bool
        var distanceGoal: Double?

        init(id: UUID, name: String, duration: TimeInterval, sortOrder: Int, trackDistance: Bool) {
            self.id = id
            self.name = name
            self.duration = duration
            self.sortOrder = sortOrder
            self.trackDistance = trackDistance
        }
    }
}

// MARK: - Schema V2
// Frozen snapshot of the CloudKit-compatible schema (attribute defaults, optional
// relationships, inverses for WorkoutTemplate.blocks and IntervalBlock.intervals).
// Do not edit — it must match existing V2 on-disk stores exactly.

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self
        ]
    }

    @Model
    final class WorkoutTemplate {
        var id: UUID = UUID()
        var name: String = ""
        var sortOrder: Int = 0
        var showHeartRateZones: Bool = false
        var createdAt: Date?
        var updatedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \IntervalBlock.template)
        var blocks: [IntervalBlock]? = []
        var isDownloaded: Bool?
        var sourceRecordName: String?
        var sourceUpdatedAt: Date?
        var originalTemplateID: UUID?
        var isPublished: Bool?
        var publishedRecordName: String?
        var creatorName: String?
        var hasAvailableUpdate: Bool?

        init() {}
    }

    @Model
    final class IntervalBlock {
        var id: UUID = UUID()
        var name: String?
        var repeatCount: Int = 1
        var sortOrder: Int = 0
        @Relationship(deleteRule: .cascade, inverse: \IntervalItem.block)
        var intervals: [IntervalItem]? = []
        @Relationship(deleteRule: .cascade, inverse: \IntervalBlock.parentBlock)
        var childBlocks: [IntervalBlock]? = []
        var parentBlock: IntervalBlock?
        var template: WorkoutTemplate?

        init() {}
    }

    @Model
    final class IntervalItem {
        var id: UUID = UUID()
        var name: String = ""
        var duration: TimeInterval = 0
        var sortOrder: Int = 0
        var trackDistance: Bool = false
        var distanceGoal: Double?
        var block: IntervalBlock?

        init() {}
    }
}

// MARK: - Schema V3
// Current live models: adds IntervalItem.isRest and the WorkoutRecord entity.

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutTemplate.self,
            IntervalBlock.self,
            IntervalItem.self,
            WorkoutRecord.self
        ]
    }
}

// MARK: - Migration Plan

enum IntervalTimerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    // V3 adds `isRest` (default false). Existing intervals named like a rest
    // ("Rest", "Active Rest", "Rest 2") are switched on so reports treat them
    // as recovery. Whole-word match so names like "Forest Run" are left alone.
    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: nil,
        didMigrate: { context in
            let intervals = try context.fetch(FetchDescriptor<IntervalItem>())
            for interval in intervals where isRestName(interval.name) {
                interval.isRest = true
            }
            try context.save()
        }
    )

    static func isRestName(_ name: String) -> Bool {
        name.range(of: #"\brest\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // V1 stored template→blocks and block→intervals as to-many relationships with
    // no inverse. V2 adds inverses, which changes how those links are stored, so the
    // links are captured by ID before migration and re-applied afterwards.
    nonisolated(unsafe) private static var blockIDsByTemplate: [UUID: [UUID]] = [:]
    nonisolated(unsafe) private static var intervalIDsByBlock: [UUID: [UUID]] = [:]

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            let templates = try context.fetch(FetchDescriptor<SchemaV1.WorkoutTemplate>())
            blockIDsByTemplate = Dictionary(
                templates.map { ($0.id, $0.blocks.map(\.id)) },
                uniquingKeysWith: { first, _ in first }
            )
            let blocks = try context.fetch(FetchDescriptor<SchemaV1.IntervalBlock>())
            intervalIDsByBlock = Dictionary(
                blocks.map { ($0.id, $0.intervals.map(\.id)) },
                uniquingKeysWith: { first, _ in first }
            )
        },
        didMigrate: { context in
            // Uses the frozen V2 types: the live models are a later schema
            let templates = try context.fetch(FetchDescriptor<SchemaV2.WorkoutTemplate>())
            let blocks = try context.fetch(FetchDescriptor<SchemaV2.IntervalBlock>())
            let intervals = try context.fetch(FetchDescriptor<SchemaV2.IntervalItem>())
            let blocksByID = Dictionary(blocks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let intervalsByID = Dictionary(intervals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            for template in templates {
                if let ids = blockIDsByTemplate[template.id] {
                    template.blocks = ids.compactMap { blocksByID[$0] }
                }
            }
            for block in blocks {
                if let ids = intervalIDsByBlock[block.id] {
                    block.intervals = ids.compactMap { intervalsByID[$0] }
                }
            }
            try context.save()

            blockIDsByTemplate = [:]
            intervalIDsByBlock = [:]
        }
    )
}
