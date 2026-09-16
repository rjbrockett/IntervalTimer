import Foundation
import SwiftData

@Model
final class IntervalItem {
    var id: UUID
    var name: String
    var duration: TimeInterval  // seconds
    var sortOrder: Int
    var trackDistance: Bool
    var distanceGoal: Double?  // in meters, nil means no goal
    
    init(id: UUID = UUID(), name: String, duration: TimeInterval, sortOrder: Int, trackDistance: Bool = false, distanceGoal: Double? = nil) {
        self.id = id
        self.name = name
        self.duration = duration
        self.sortOrder = sortOrder
        self.trackDistance = trackDistance
        self.distanceGoal = distanceGoal
    }
    
    /// Create a deep copy with a new UUID
    func duplicate() -> IntervalItem {
        IntervalItem(
            id: UUID(),
            name: name,
            duration: duration,
            sortOrder: sortOrder,
            trackDistance: trackDistance,
            distanceGoal: distanceGoal
        )
    }
}
