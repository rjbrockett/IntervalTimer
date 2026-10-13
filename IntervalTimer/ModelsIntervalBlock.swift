import Foundation
import SwiftData

/// Represents either an interval or a child block, for unified sorting within a parent block
enum BlockChild: Identifiable {
    case interval(IntervalItem)
    case childBlock(IntervalBlock)
    
    var id: UUID {
        switch self {
        case .interval(let item): return item.id
        case .childBlock(let block): return block.id
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .interval(let item): return item.sortOrder
        case .childBlock(let block): return block.sortOrder
        }
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
    
    /// All children (intervals + child blocks) sorted together by sortOrder
    var sortedChildren: [BlockChild] {
        let intervalItems: [BlockChild] = intervals.map { .interval($0) }
        let blockItems: [BlockChild] = childBlocks.map { .childBlock($0) }
        return (intervalItems + blockItems).sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Next available sortOrder across both intervals and child blocks
    var nextChildSortOrder: Int {
        let maxInterval = intervals.map(\.sortOrder).max() ?? -1
        let maxBlock = childBlocks.map(\.sortOrder).max() ?? -1
        return max(maxInterval, maxBlock) + 1
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
