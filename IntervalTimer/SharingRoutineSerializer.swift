import Foundation
import SwiftData

/// Converts between SwiftData models and Codable payloads for CloudKit sharing
struct RoutineSerializer {
    
    // MARK: - Serialize (SwiftData → Codable)
    
    static func serialize(template: WorkoutTemplate, creatorName: String) -> SharedRoutinePayload {
        SharedRoutinePayload(
            originalTemplateID: template.originalTemplateID ?? template.id,
            name: template.name,
            showHeartRateZones: template.showHeartRateZones,
            creatorName: creatorName,
            updatedAt: Date(),
            blocks: template.sortedBlocks.map { serializeBlock($0) }
        )
    }
    
    private static func serializeBlock(_ block: IntervalBlock) -> SharedBlockPayload {
        SharedBlockPayload(
            name: block.name,
            repeatCount: block.repeatCount,
            sortOrder: block.sortOrder,
            intervals: block.sortedIntervals.map { serializeInterval($0) },
            childBlocks: block.sortedChildBlocks.map { serializeBlock($0) }
        )
    }
    
    private static func serializeInterval(_ interval: IntervalItem) -> SharedIntervalPayload {
        SharedIntervalPayload(
            name: interval.name,
            duration: interval.duration,
            sortOrder: interval.sortOrder,
            trackDistance: interval.trackDistance,
            distanceGoal: interval.distanceGoal
        )
    }
    
    // MARK: - Deserialize (Codable → SwiftData)
    
    /// Creates a new WorkoutTemplate from a shared payload.
    /// The template is marked as downloaded and linked to the source.
    static func deserialize(
        payload: SharedRoutinePayload,
        sourceRecordName: String,
        nextSortOrder: Int
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(
            name: payload.name,
            sortOrder: nextSortOrder,
            showHeartRateZones: payload.showHeartRateZones,
            blocks: payload.blocks.map { deserializeBlock($0) },
            isDownloaded: true,
            sourceRecordName: sourceRecordName,
            sourceUpdatedAt: payload.updatedAt,
            originalTemplateID: payload.originalTemplateID,
            creatorName: payload.creatorName,
            hasAvailableUpdate: false
        )
        return template
    }
    
    private static func deserializeBlock(_ payload: SharedBlockPayload) -> IntervalBlock {
        IntervalBlock(
            name: payload.name,
            repeatCount: payload.repeatCount,
            sortOrder: payload.sortOrder,
            intervals: payload.intervals.map { deserializeInterval($0) },
            childBlocks: payload.childBlocks.map { deserializeBlock($0) }
        )
    }
    
    private static func deserializeInterval(_ payload: SharedIntervalPayload) -> IntervalItem {
        IntervalItem(
            name: payload.name,
            duration: payload.duration,
            sortOrder: payload.sortOrder,
            trackDistance: payload.trackDistance,
            distanceGoal: payload.distanceGoal
        )
    }
    
    // MARK: - JSON Encoding/Decoding
    
    static func encode(payload: SharedRoutinePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
    
    static func decode(data: Data) throws -> SharedRoutinePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedRoutinePayload.self, from: data)
    }
}
