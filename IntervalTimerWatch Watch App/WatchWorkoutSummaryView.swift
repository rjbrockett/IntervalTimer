import SwiftUI

/// Compact post-workout summary shown on the watch. The full report
/// (charts, interval breakdown) is on iPhone via iCloud sync.
struct WatchWorkoutSummaryView: View {
    let record: WorkoutRecord
    var onDone: () -> Void

    private var splits: [IntervalSplit] { record.splits }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Label(
                        record.isPartial ? "Ended Early" : "Complete",
                        systemImage: record.isPartial ? "flag.checkered" : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(record.isPartial ? .orange : .green)

                    Text(record.routineName)
                        .font(.headline)
                        .lineLimit(2)
                }

                metric("Total Time", TimeFormatter.formatClock(record.activeDuration), color: .yellow)

                if let distance = record.totalDistance {
                    metric("Distance", String(format: "%.2f mi", distance / 1609.34), color: .green)
                }
                if let calories = record.activeCalories {
                    metric("Active Calories", "\(Int(calories.rounded())) kcal", color: .pink)
                }
                if let avg = record.avgHeartRate {
                    metric("Avg Heart Rate", "\(avg) BPM", color: .red)
                }
                if let max = record.maxHeartRate {
                    metric("Max Heart Rate", "\(max) BPM", color: .red)
                }

                metric("Intervals", intervalsSummary, color: .blue)

                Text("Full report on iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// e.g. "12 done · 1 skipped"
    private var intervalsSummary: String {
        let done = splits.filter { $0.outcome == .completed }.count
        let skipped = splits.filter { $0.outcome == .skipped }.count
        return skipped > 0 ? "\(done) done · \(skipped) skipped" : "\(done) done"
    }

    private func metric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
