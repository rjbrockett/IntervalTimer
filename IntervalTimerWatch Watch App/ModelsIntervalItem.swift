import Foundation
import SwiftData

@Model
final class IntervalItem {
    // CloudKit requires every attribute to be optional or have a default value,
    // and every relationship to be optional with an inverse.
    var id: UUID = UUID()
    var name: String = ""
    var duration: TimeInterval = 0  // seconds
    var sortOrder: Int = 0
    var trackDistance: Bool = false
    var distanceGoal: Double?  // in meters, nil means no goal
    /// Rest/recovery interval (shown as recovery rather than work in workout reports)
    var isRest: Bool = false
    
    /// Inverse of IntervalBlock.intervals
    var block: IntervalBlock?
    
    init(id: UUID = UUID(), name: String, duration: TimeInterval, sortOrder: Int, trackDistance: Bool = false, distanceGoal: Double? = nil, isRest: Bool = false) {
        self.id = id
        self.name = name
        self.duration = duration
        self.sortOrder = sortOrder
        self.trackDistance = trackDistance
        self.distanceGoal = distanceGoal
        self.isRest = isRest
    }
    
    /// Create a deep copy with a new UUID
    func duplicate() -> IntervalItem {
        IntervalItem(
            id: UUID(),
            name: name,
            duration: duration,
            sortOrder: sortOrder,
            trackDistance: trackDistance,
            distanceGoal: distanceGoal,
            isRest: isRest
        )
    }
}
