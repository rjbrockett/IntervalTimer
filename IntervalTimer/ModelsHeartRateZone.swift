import Foundation

/// Apple-standard heart rate zones based on percentage of max heart rate (220 - age)
enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1  // 50-60% — Zone 1
    case zone2 = 2  // 60-70% — Zone 2
    case zone3 = 3  // 70-80% — Zone 3
    case zone4 = 4  // 80-90% — Zone 4
    case zone5 = 5  // 90-100% — Zone 5

    var name: String {
        "Zone \(rawValue)"
    }

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .zone1: return (0.53, 0.73, 0.87)  // Light blue
        case .zone2: return (0.33, 0.78, 0.47)  // Green
        case .zone3: return (0.95, 0.85, 0.15)  // Yellow
        case .zone4: return (0.95, 0.55, 0.15)  // Orange
        case .zone5: return (0.92, 0.25, 0.20)  // Red
        }
    }

    static func from(percentage: Double) -> HeartRateZone {
        switch percentage {
        case ..<60: return .zone1
        case 60..<70: return .zone2
        case 70..<80: return .zone3
        case 80..<90: return .zone4
        default: return .zone5
        }
    }

    /// Zone for a heart rate, or nil when max heart rate is unknown
    static func from(bpm: Int, maxHeartRate: Int) -> HeartRateZone? {
        guard maxHeartRate > 0, bpm > 0 else { return nil }
        return from(percentage: Double(bpm) / Double(maxHeartRate) * 100)
    }
}
