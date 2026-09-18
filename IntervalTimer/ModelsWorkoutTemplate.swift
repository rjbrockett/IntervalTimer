import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var sortOrder: Int
    var showHeartRateZones: Bool
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) 
    var blocks: [IntervalBlock]
    
    init(id: UUID = UUID(), 
         name: String,
         sortOrder: Int = 0,
         showHeartRateZones: Bool = false,
         createdAt: Date = Date(), 
         updatedAt: Date = Date(),
         blocks: [IntervalBlock] = []) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.showHeartRateZones = showHeartRateZones
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks
    }
    
    /// Computed property for sorted blocks
    var sortedBlocks: [IntervalBlock] {
        blocks.sorted { $0.sortOrder < $1.sortOrder }
    }
}
