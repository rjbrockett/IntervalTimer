import Foundation
import SwiftData

@Model
final class IntervalBlock {
    var id: UUID
    var name: String?
    var repeatCount: Int
    var sortOrder: Int
    
    @Relationship(deleteRule: .cascade) 
    var intervals: [IntervalItem]
    
    init(id: UUID = UUID(), 
         name: String? = nil, 
         repeatCount: Int = 1, 
         sortOrder: Int,
         intervals: [IntervalItem] = []) {
        self.id = id
        self.name = name
        self.repeatCount = repeatCount
        self.sortOrder = sortOrder
        self.intervals = intervals
    }
    
    /// Create a deep copy with new UUIDs for the block and all intervals
    func duplicate() -> IntervalBlock {
        let newIntervals = intervals.map { $0.duplicate() }
        return IntervalBlock(
            id: UUID(),
            name: name,
            repeatCount: repeatCount,
            sortOrder: sortOrder,
            intervals: newIntervals
        )
    }
}
