import Foundation
import SwiftData

@Model
final class IntervalItem {
    var id: UUID
    var name: String
    var duration: TimeInterval  // seconds
    var sortOrder: Int
    
    init(id: UUID = UUID(), name: String, duration: TimeInterval, sortOrder: Int) {
        self.id = id
        self.name = name
        self.duration = duration
        self.sortOrder = sortOrder
    }
    
    /// Create a deep copy with a new UUID
    func duplicate() -> IntervalItem {
        IntervalItem(
            id: UUID(),
            name: name,
            duration: duration,
            sortOrder: sortOrder
        )
    }
}
