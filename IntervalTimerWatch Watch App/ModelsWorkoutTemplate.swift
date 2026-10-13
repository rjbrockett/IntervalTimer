import Foundation
import SwiftData

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
    
    // MARK: - Sharing fields
    // Bool fields are optional because CloudKit requires non-relationship properties
    // to be optional or have static schema-level defaults. Treat nil as false.
    
    /// True if this template was downloaded from another user (read-only, appears in Downloaded tab)
    var isDownloaded: Bool?
    /// CKRecord.ID.recordName of the public-database record this was downloaded from
    var sourceRecordName: String?
    /// The updatedAt timestamp from the source at the time of last download/update
    var sourceUpdatedAt: Date?
    /// Stable UUID identifying "the same routine" across all users (for future stats comparison)
    var originalTemplateID: UUID?
    /// Whether this routine has been published to the CloudKit public database
    var isPublished: Bool?
    /// CKRecord.ID.recordName of this routine's public record (if published)
    var publishedRecordName: String?
    /// Display name of the creator (set when downloading)
    var creatorName: String?
    /// True when a newer version is available from the source
    var hasAvailableUpdate: Bool?
    
    init(id: UUID = UUID(), 
         name: String,
         sortOrder: Int = 0,
         showHeartRateZones: Bool = false,
         createdAt: Date? = Date(), 
         updatedAt: Date? = Date(),
         blocks: [IntervalBlock] = [],
         isDownloaded: Bool? = false,
         sourceRecordName: String? = nil,
         sourceUpdatedAt: Date? = nil,
         originalTemplateID: UUID? = nil,
         isPublished: Bool? = false,
         publishedRecordName: String? = nil,
         creatorName: String? = nil,
         hasAvailableUpdate: Bool? = false) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.showHeartRateZones = showHeartRateZones
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks
        self.isDownloaded = isDownloaded
        self.sourceRecordName = sourceRecordName
        self.sourceUpdatedAt = sourceUpdatedAt
        self.originalTemplateID = originalTemplateID
        self.isPublished = isPublished
        self.publishedRecordName = publishedRecordName
        self.creatorName = creatorName
        self.hasAvailableUpdate = hasAvailableUpdate
    }
    
    /// Computed property for sorted blocks
    var sortedBlocks: [IntervalBlock] {
        blocks.sorted { $0.sortOrder < $1.sortOrder }
    }
}
