import SwiftUI

/// One workout in a history list
struct WorkoutRecordRow: View {
    let record: WorkoutRecord
    /// Show the routine name as the title (History tab); otherwise the date is the title
    var showsRoutineName = true

    private var dateText: String {
        guard let start = record.startedAt else { return "" }
        return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(showsRoutineName ? record.routineName : dateText)
                        .font(.headline)
                        .lineLimit(1)
                    if record.isPartial {
                        Text("Partial")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(TimeFormatter.formatClock(record.activeDuration))
                    .font(.headline)
                    .monospacedDigit()
                if let avg = record.avgHeartRate {
                    Label("\(avg)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .monospacedDigit()
                } else if let distance = record.totalDistance {
                    Text(ReportFormat.miles(distance))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        showsRoutineName
            ? [dateText, record.deviceName].filter { !$0.isEmpty }.joined(separator: " · ")
            : record.deviceName
    }
}
