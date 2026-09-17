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
    
    @Relationship(deleteRule: .cascade, inverse: \IntervalBlock.parentBlock)
    var childBlocks: [IntervalBlock]
    
    var parentBlock: IntervalBlock?
    
    /// True if this block contains sub-blocks rather than intervals
    var isGroup: Bool {
        !childBlocks.isEmpty
    }
    
    /// Sorted child blocks by sortOrder
    var sortedChildBlocks: [IntervalBlock] {
        childBlocks.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Sorted intervals by sortOrder
    var sortedIntervals: [IntervalItem] {
        intervals.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    init(id: UUID = UUID(), 
         name: String? = nil, 
         repeatCount: Int = 1, 
         sortOrder: Int,
         intervals: [IntervalItem] = [],
         childBlocks: [IntervalBlock] = [],
         parentBlock: IntervalBlock? = nil) {
        self.id = id
        self.name = name
        self.repeatCount = repeatCount
        self.sortOrder = sortOrder
        self.intervals = intervals
        self.childBlocks = childBlocks
        self.parentBlock = parentBlock
    }
    
    /// Create a deep copy with new UUIDs for the block and all children
    func duplicate() -> IntervalBlock {
        let newIntervals = intervals.map { $0.duplicate() }
        let newChildBlocks = childBlocks.map { $0.duplicate() }
        return IntervalBlock(
            id: UUID(),
            name: name,
            repeatCount: repeatCount,
            sortOrder: sortOrder,
            intervals: newIntervals,
            childBlocks: newChildBlocks
        )
    }
}
