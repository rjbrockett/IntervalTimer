import SwiftUI

/// Groups a record's splits for display: rounds (outermost block repeats)
/// containing sub-block sections, plus per-exercise totals.
/// Decodes the record once so views don't re-decode on every render.
struct WorkoutReport {
    struct Round: Identifiable {
        let id: String
        /// e.g. "Circuit · Round 1 of 3", or just the block name when it doesn't repeat
        let title: String
        /// e.g. "Round 1" — short label for chart axes
        let shortTitle: String
        let sections: [Section]
        let startOffset: TimeInterval
        let duration: TimeInterval
        let avgHeartRate: Int?
        let peakHeartRate: Int?

        var splits: [IntervalSplit] { sections.flatMap(\.splits) }
    }

    struct Section: Identifiable {
        let id: String
        /// e.g. "UPPER BODY ×2"; nil for intervals sitting directly in the round
        let header: String?
        let splits: [IntervalSplit]
    }

    struct Exercise: Identifiable {
        let id: UUID
        let name: String
        let count: Int
        let avgDuration: TimeInterval
        let avgHeartRate: Int?
        let peakHeartRate: Int?
        let totalDistance: Double?
    }

    let splits: [IntervalSplit]
    let rounds: [Round]
    let exercises: [Exercise]
    let samples: [HeartRateSample]

    init(record: WorkoutRecord) {
        let splits = record.splits
        self.splits = splits
        self.samples = record.heartRateSamples
        self.rounds = Self.makeRounds(splits)
        self.exercises = Self.makeExercises(splits)
    }

    // MARK: - Labels

    /// "Pushups · Set 2" when the interval's own block repeats
    static func label(for split: IntervalSplit) -> String {
        guard !split.isRest, split.context.count >= 2,
              let innermost = split.context.last, innermost.repeatCount > 1 else {
            return split.name
        }
        return "\(split.name) · Set \(innermost.iteration)"
    }

    /// Weighted by time so long intervals count more than short ones
    static func averageHeartRate(_ splits: [IntervalSplit]) -> Int? {
        let weighted = splits.compactMap { split in
            split.avgHeartRate.map { (Double($0) * split.actualDuration, split.actualDuration) }
        }
        let totalTime = weighted.reduce(0) { $0 + $1.1 }
        guard totalTime > 0 else { return nil }
        return Int((weighted.reduce(0) { $0 + $1.0 } / totalTime).rounded())
    }

    // MARK: - Grouping

    /// Consecutive splits from the same outermost block repeat form a round.
    /// Consecutive (not global) grouping keeps going back/restarting in order.
    private static func makeRounds(_ splits: [IntervalSplit]) -> [Round] {
        var groups: [(key: String, splits: [IntervalSplit])] = []
        for split in splits {
            let key = split.context.first.map { "\($0.blockID)-\($0.iteration)" } ?? "workout"
            if groups.last?.key == key {
                groups[groups.count - 1].splits.append(split)
            } else {
                groups.append((key, [split]))
            }
        }

        return groups.enumerated().map { index, group in
            let outer = group.splits.first?.context.first
            let name = outer?.name ?? "Workout"
            let title: String
            let shortTitle: String
            if let outer, outer.repeatCount > 1 {
                title = "\(name) · Round \(outer.iteration) of \(outer.repeatCount)"
                shortTitle = "Round \(outer.iteration)"
            } else {
                title = name
                shortTitle = name
            }
            return Round(
                id: "\(index)-\(group.key)",
                title: title,
                shortTitle: shortTitle,
                sections: makeSections(group.splits, roundIndex: index),
                startOffset: group.splits.first?.startOffset ?? 0,
                duration: group.splits.reduce(0) { $0 + $1.actualDuration },
                avgHeartRate: averageHeartRate(group.splits),
                peakHeartRate: group.splits.compactMap(\.peakHeartRate).max()
            )
        }
    }

    /// Within a round, consecutive splits from the same second-level block share a header
    private static func makeSections(_ splits: [IntervalSplit], roundIndex: Int) -> [Section] {
        var groups: [(key: String, header: String?, splits: [IntervalSplit])] = []
        for split in splits {
            let sub = split.context.count >= 2 ? split.context[1] : nil
            let key = sub.map { $0.blockID.uuidString } ?? "direct"
            if groups.last?.key == key {
                groups[groups.count - 1].splits.append(split)
            } else {
                let header = sub.map { block -> String in
                    let name = (block.name ?? "Block").uppercased()
                    return block.repeatCount > 1 ? "\(name) ×\(block.repeatCount)" : name
                }
                groups.append((key, header, [split]))
            }
        }
        return groups.enumerated().map { index, group in
            Section(id: "\(roundIndex)-\(index)-\(group.key)", header: group.header, splits: group.splits)
        }
    }

    /// Work intervals grouped by the routine interval they came from
    private static func makeExercises(_ splits: [IntervalSplit]) -> [Exercise] {
        var order: [UUID] = []
        var byID: [UUID: [IntervalSplit]] = [:]
        for split in splits where !split.isRest {
            if byID[split.intervalID] == nil { order.append(split.intervalID) }
            byID[split.intervalID, default: []].append(split)
        }
        return order.compactMap { id in
            guard let group = byID[id], let first = group.first else { return nil }
            let distances = group.compactMap(\.distance)
            return Exercise(
                id: id,
                name: first.name,
                count: group.count,
                avgDuration: group.reduce(0) { $0 + $1.actualDuration } / Double(group.count),
                avgHeartRate: averageHeartRate(group),
                peakHeartRate: group.compactMap(\.peakHeartRate).max(),
                totalDistance: distances.isEmpty ? nil : distances.reduce(0, +)
            )
        }
    }
}

// MARK: - Preview data

#if DEBUG
extension WorkoutRecord {
    /// A 3-round HIIT circuit (Upper Body ×2, Lower Body ×2 per round) with
    /// simulated heart rate, for previews
    static func previewHIIT(withHeartRate: Bool = true) -> WorkoutRecord {
        let circuitID = UUID(), upperID = UUID(), lowerID = UUID()
        let pushupsID = UUID(), squatsID = UUID(), restID = UUID()
        var splits: [IntervalSplit] = []
        var samples: [HeartRateSample] = []
        var t: TimeInterval = 0
        var hr = 100.0

        for round in 1...3 {
            for (blockID, blockName, exerciseID, exercise) in [(upperID, "Upper Body", pushupsID, "Pushups"),
                                                                (lowerID, "Lower Body", squatsID, "Squats")] {
                for set in 1...2 {
                    let context = [
                        BlockContext(blockID: circuitID, name: "Circuit", iteration: round, repeatCount: 3),
                        BlockContext(blockID: blockID, name: blockName, iteration: set, repeatCount: 2)
                    ]
                    for (isRest, duration) in [(false, 30.0), (true, 15.0)] {
                        let startHR = hr
                        var values: [Int] = []
                        for second in stride(from: 0, to: duration, by: 1) {
                            // Climbs during work (a little more each round), drops during rest
                            let target = isRest ? 128.0 : 148.0 + Double(round) * 7
                            hr += (target - hr) * (isRest ? 0.09 : 0.07)
                            values.append(Int(hr))
                            if Int(t + second) % 5 == 0 {
                                samples.append(HeartRateSample(offset: t + second, bpm: Int(hr)))
                            }
                        }
                        splits.append(IntervalSplit(
                            intervalID: isRest ? restID : exerciseID,
                            name: isRest ? "Rest" : exercise,
                            isRest: isRest,
                            plannedDuration: duration,
                            actualDuration: duration,
                            startOffset: t,
                            outcome: .completed,
                            avgHeartRate: withHeartRate ? values.reduce(0, +) / values.count : nil,
                            peakHeartRate: withHeartRate ? values.max() : nil,
                            recoveredBPM: withHeartRate && isRest ? Int(startHR - hr) : nil,
                            context: context
                        ))
                        t += duration
                    }
                }
            }
        }

        let start = Calendar.current.date(bySettingHour: 7, minute: 42, second: 0, of: Date()) ?? Date()
        let record = WorkoutRecord(
            startedAt: start,
            endedAt: start.addingTimeInterval(t),
            deviceName: withHeartRate ? "Apple Watch" : "iPhone",
            isPartial: false,
            templateID: UUID(),
            originalTemplateID: nil,
            routineName: "3x HIIT Circuit",
            activeDuration: t
        )
        if withHeartRate {
            let bpms = samples.map(\.bpm)
            record.avgHeartRate = bpms.reduce(0, +) / bpms.count
            record.maxHeartRate = bpms.max()
            record.activeCalories = 98
            record.zoneSeconds = [5, 52, 266, 214, 3]
            record.heartRateSamples = samples
        }
        record.splits = splits
        return record
    }
}
#endif

// MARK: - Shared formatting

enum ReportFormat {
    static func miles(_ meters: Double) -> String {
        String(format: "%.2f mi", meters / 1609.34)
    }

    /// "Today, 7:42 – 7:51 AM"
    static func timeRange(_ record: WorkoutRecord) -> String {
        guard let start = record.startedAt else { return "" }
        let day: String
        let calendar = Calendar.current
        if calendar.isDateInToday(start) {
            day = "Today"
        } else if calendar.isDateInYesterday(start) {
            day = "Yesterday"
        } else {
            day = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        guard let end = record.endedAt, end > start else {
            return "\(day), \(start.formatted(date: .omitted, time: .shortened))"
        }
        return "\(day), \((start..<end).formatted(.interval.hour().minute()))"
    }

    static func zoneColor(_ zone: HeartRateZone) -> Color {
        let c = zone.color
        return Color(red: c.red, green: c.green, blue: c.blue)
    }

    /// Matches the editor's nesting colors
    static func depthColor(_ depth: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink]
        return colors[max(0, depth) % colors.count]
    }
}
