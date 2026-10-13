import Foundation
import SwiftData

/// Checks downloaded routines for updates from their creators on app launch
@MainActor
struct RoutineUpdateChecker {
    
    /// Checks all downloaded routines for available updates from the CloudKit public database.
    static func checkAllForUpdates(context: ModelContext) async {
        let service = CloudKitSharingService()
        
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate<WorkoutTemplate> { template in
                template.isDownloaded == true && template.sourceRecordName != nil
            }
        )
        
        guard let downloaded = try? context.fetch(descriptor) else { return }
        
        for template in downloaded {
            guard let recordName = template.sourceRecordName else { continue }
            
            if let _ = await service.checkForUpdate(
                sourceRecordName: recordName,
                localUpdatedAt: template.sourceUpdatedAt
            ) {
                template.hasAvailableUpdate = true
            }
        }
        
        try? context.save()
    }
    
    /// Accepts an update for a downloaded routine: fetches the latest version and replaces blocks.
    static func acceptUpdate(for template: WorkoutTemplate, context: ModelContext) async throws {
        guard let recordName = template.sourceRecordName else { return }
        
        let service = CloudKitSharingService()
        let (payload, _) = try await service.fetchRoutine(recordName: recordName)
        
        // Delete existing blocks (cascade will remove intervals and child blocks)
        for block in template.blocks {
            context.delete(block)
        }
        
        // Deserialize new blocks from the updated payload
        let newBlocks = payload.blocks.map { deserializeBlock($0) }
        template.blocks = newBlocks
        
        // Update metadata
        template.name = payload.name
        template.showHeartRateZones = payload.showHeartRateZones
        template.sourceUpdatedAt = payload.updatedAt
        template.creatorName = payload.creatorName
        template.hasAvailableUpdate = false
        template.updatedAt = Date()
        
        try context.save()
    }
    
    /// Unlinks a downloaded routine — moves it to "My Routines" as an editable copy.
    static func unlinkRoutine(_ template: WorkoutTemplate, context: ModelContext) throws {
        template.isDownloaded = false
        template.sourceRecordName = nil
        template.hasAvailableUpdate = false
        // Keep originalTemplateID for future stats correlation
        // Keep creatorName for provenance (optional, could clear)
        
        try context.save()
    }
    
    // MARK: - Private deserialization helpers
    
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
}
