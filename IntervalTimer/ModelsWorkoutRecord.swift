import Foundation
import SwiftData

/// One completed (or partially completed) run of a routine.
///
/// Per-interval splits and the heart-rate series are stored as encoded blobs
/// rather than child models, so a record syncs through CloudKit as a single
/// unit and never appears on another device with only some of its splits.
/// There's intentionally no relationship to `WorkoutTemplate`: deleting or
/// renaming a routine keeps its history intact.
@Model
final class WorkoutRecord {
    // CloudKit requires every attribute to be optional or have a default value.
    var id: UUID = UUID()
    var startedAt: Date?
    var endedAt: Date?
    /// "Apple Watch" or "iPhone"
    var deviceName: String = ""
    /// True if the workout was ended before the last interval finished
    var isPartial: Bool = false

    /// The routine this was run from (no relationship — see type comment)
    var templateID: UUID?
    var originalTemplateID: UUID?
    /// Routine name at the time of the workout
    var routineName: String = ""

    /// Time spent running, excluding pauses (seconds)
    var activeDuration: TimeInterval = 0
    /// Meters; nil when no interval tracked distance
    var totalDistance: Double?
    /// Kilocalories; watch only
    var activeCalories: Double?
    var avgHeartRate: Int?
    var maxHeartRate: Int?

    // Encoded payloads — use the computed accessors below
    var zoneSecondsData: Data?
    var splitsData: Data?
    var heartRateData: Data?

    init(id: UUID = UUID(),
         startedAt: Date?,
         endedAt: Date?,
         deviceName: String,
         isPartial: Bool,
         templateID: UUID?,
         originalTemplateID: UUID?,
         routineName: String,
         activeDuration: TimeInterval) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deviceName = deviceName
        self.isPartial = isPartial
        self.templateID = templateID
        self.originalTemplateID = originalTemplateID
        self.routineName = routineName
        self.activeDuration = activeDuration
    }

    // MARK: - Decoded accessors

    /// Seconds spent in each heart rate zone (5 entries), nil when unavailable
    var zoneSeconds: [Int]? {
        get { Self.decode([Int].self, from: zoneSecondsData) }
        set { zoneSecondsData = Self.encode(newValue) }
    }

    /// Intervals in the order they were performed
    var splits: [IntervalSplit] {
        get { Self.decode([IntervalSplit].self, from: splitsData) ?? [] }
        set { splitsData = Self.encode(newValue) }
    }

    /// Heart rate sampled through the workout (empty without a watch)
    var heartRateSamples: [HeartRateSample] {
        get { Self.decode([HeartRateSample].self, from: heartRateData) ?? [] }
        set { heartRateData = Self.encode(newValue.isEmpty ? nil : newValue) }
    }

    var hasHeartRate: Bool {
        avgHeartRate != nil
    }

    private static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Report value types

/// Where an interval sat in the routine: one entry per enclosing block,
/// outermost first. The outermost gives "Round 2 of 3", inner ones give
/// sub-block headers, and the innermost iteration gives "Set n".
struct BlockContext: Codable, Hashable {
    var blockID: UUID
    var name: String?
    /// 1-based repeat number of this block
    var iteration: Int
    var repeatCount: Int
}

/// One performed interval in a workout report
struct IntervalSplit: Codable, Hashable, Identifiable {
    enum Outcome: String, Codable {
        /// Timer ran out (or a manual interval was advanced)
        case completed
        /// Skipped ahead before the timer ran out
        case skipped
        /// Restarted or went back to the previous interval
        case restarted
        /// The workout was ended during this interval
        case endedEarly
    }

    var id: UUID = UUID()
    /// The routine interval this came from; groups repeats of the same exercise
    var intervalID: UUID
    var name: String
    var isRest: Bool
    /// 0 for manual-advance intervals
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    /// Seconds into the workout (active time) when this interval began
    var startOffset: TimeInterval
    /// Meters covered during this interval, when it tracked distance
    var distance: Double?
    var distanceGoal: Double?
    var outcome: Outcome
    var avgHeartRate: Int?
    var peakHeartRate: Int?
    /// Rest only: heart rate drop from the start to the end of the rest
    var recoveredBPM: Int?
    var context: [BlockContext]
}

/// A heart rate reading at a point in the workout (active time)
struct HeartRateSample: Codable, Hashable {
    var offset: TimeInterval
    var bpm: Int
}
