import SwiftUI

/// Per-interval breakdown of a workout: by round (with sub-block sections)
/// or by exercise across the whole workout.
struct WorkoutIntervalsView: View {
    let record: WorkoutRecord
    let report: WorkoutReport

    private enum Mode: String, CaseIterable {
        case rounds = "Rounds"
        case exercises = "Exercises"
    }

    @State private var mode: Mode = .rounds
    /// Round cards currently expanded (the first starts open)
    @State private var expandedRounds: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch mode {
                case .rounds:
                    ForEach(report.rounds) { round in
                        RoundCard(
                            round: round,
                            showsHeartRate: record.hasHeartRate,
                            isExpanded: Binding(
                                get: { expandedRounds.contains(round.id) },
                                set: { expanded in
                                    if expanded {
                                        expandedRounds.insert(round.id)
                                    } else {
                                        expandedRounds.remove(round.id)
                                    }
                                }
                            )
                        )
                    }
                case .exercises:
                    ExercisesCard(exercises: report.exercises, showsHeartRate: record.hasHeartRate)
                    CompareExercisesCard(exercises: report.exercises, showsHeartRate: record.hasHeartRate)
                }
            }
            .padding()
        }
        .background(ReportFormat.groupedBackground)
        .navigationTitle("By Interval")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if expandedRounds.isEmpty, let first = report.rounds.first {
                expandedRounds = [first.id]
            }
        }
    }
}

#Preview("By Interval") {
    let record = WorkoutRecord.previewHIIT()
    NavigationStack {
        WorkoutIntervalsView(record: record, report: WorkoutReport(record: record))
    }
}

// MARK: - Rounds

private struct RoundCard: View {
    let round: WorkoutReport.Round
    let showsHeartRate: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ReportFormat.depthColor(0))
                        .frame(width: 4, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapse" : "Expand")

            if isExpanded {
                Divider()
                    .padding(.vertical, 10)
                ForEach(Array(round.sections.enumerated()), id: \.element.id) { index, section in
                    // Column labels ride along with the first header row
                    if index == 0 || section.header != nil {
                        sectionHeader(section.header, showsColumns: index == 0)
                            .padding(.top, index == 0 ? 0 : 8)
                    }
                    ForEach(section.splits) { split in
                        SplitRow(split: split, showsHeartRate: showsHeartRate)
                    }
                }
            }
        }
        .padding(14)
        .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    /// "3:00 · Avg 140 · Peak 160 BPM"
    private var subtitle: String {
        var parts = [TimeFormatter.formatClock(round.duration)]
        if showsHeartRate {
            if let avg = round.avgHeartRate { parts.append("Avg \(avg)") }
            if let peak = round.peakHeartRate { parts.append("Peak \(peak) BPM") }
        }
        return parts.joined(separator: " · ")
    }

    /// Sub-block title (e.g. "UPPER BODY ×2") with optional TIME / AVG (or DIST) column labels
    private func sectionHeader(_ title: String?, showsColumns: Bool) -> some View {
        HStack {
            Text(title ?? "")
            Spacer()
            if showsColumns {
                Text("TIME")
                    .frame(width: 48, alignment: .trailing)
                Text(showsHeartRate ? "AVG" : "DIST")
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
    }
}

private struct SplitRow: View {
    let split: IntervalSplit
    let showsHeartRate: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ReportFormat.depthColor(max(1, split.context.count - 1)).opacity(split.isRest ? 0.35 : 1))
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(WorkoutReport.label(for: split))
                    .font(.body)
                    .lineLimit(1)
                detailLine
            }

            Spacer(minLength: 8)

            Text(TimeFormatter.formatClock(split.actualDuration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            Group {
                if showsHeartRate {
                    Text(split.avgHeartRate.map(String.init) ?? "–")
                } else {
                    Text(split.distance.map { String(format: "%.2f", $0 / 1609.34) } ?? "–")
                }
            }
            .font(.body.weight(.bold))
            .monospacedDigit()
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    /// "Peak 147 BPM", "Recovered 20 BPM", distance vs goal, and skip/restart tags
    @ViewBuilder
    private var detailLine: some View {
        HStack(spacing: 6) {
            if split.isRest {
                if showsHeartRate, let recovered = split.recoveredBPM, recovered > 0 {
                    Text("Recovered \(recovered) BPM")
                        .foregroundStyle(.green)
                }
            } else if showsHeartRate, let peak = split.peakHeartRate {
                Text("Peak \(peak) BPM")
                    .foregroundStyle(.secondary)
            }

            if let distance = split.distance {
                if let goal = split.distanceGoal, goal > 0 {
                    let hit = distance >= goal
                    Label(
                        "\(ReportFormat.miles(distance)) / \(ReportFormat.miles(goal))",
                        systemImage: hit ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(hit ? .green : .secondary)
                } else if showsHeartRate {
                    Text(ReportFormat.miles(distance))
                        .foregroundStyle(.secondary)
                }
            }

            if let tag = outcomeTag {
                Text(tag)
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var outcomeTag: String? {
        switch split.outcome {
        case .completed: return nil
        case .skipped: return "Skipped"
        case .restarted: return "Restarted"
        case .endedEarly: return "Ended early"
        }
    }
}

// MARK: - Exercises

private struct ExercisesCard: View {
    let exercises: [WorkoutReport.Exercise]
    let showsHeartRate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EXERCISE")
                Spacer()
                Text("AVG TIME")
                    .frame(width: 64, alignment: .trailing)
                if showsHeartRate {
                    Text("AVG")
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)

            if exercises.isEmpty {
                Text("No work intervals recorded")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            ForEach(exercises) { exercise in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ReportFormat.depthColor(1))
                        .frame(width: 4, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(exercise.count > 1 ? "\(exercise.name) ×\(exercise.count)" : exercise.name)
                            .lineLimit(1)
                        Group {
                            if showsHeartRate, let peak = exercise.peakHeartRate {
                                Text("Peak \(peak) BPM")
                            } else if let distance = exercise.totalDistance {
                                Text("\(ReportFormat.miles(distance)) total")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(TimeFormatter.formatClock(exercise.avgDuration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 64, alignment: .trailing)
                    if showsHeartRate {
                        Text(exercise.avgHeartRate.map(String.init) ?? "–")
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Horizontal bars comparing exercises by average heart rate
/// (or average time when there's no heart rate data)
private struct CompareExercisesCard: View {
    let exercises: [WorkoutReport.Exercise]
    let showsHeartRate: Bool

    private func value(_ exercise: WorkoutReport.Exercise) -> Double? {
        showsHeartRate ? exercise.avgHeartRate.map(Double.init) : exercise.avgDuration
    }

    private func label(_ exercise: WorkoutReport.Exercise) -> String {
        if showsHeartRate {
            return exercise.avgHeartRate.map(String.init) ?? "–"
        }
        return TimeFormatter.formatClock(exercise.avgDuration)
    }

    var body: some View {
        let maxValue = exercises.compactMap(value).max() ?? 0
        if exercises.count > 1, maxValue > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Compare Exercises")
                    .font(.headline)
                ForEach(exercises) { exercise in
                    HStack(spacing: 10) {
                        Text(exercise.count > 1 ? "\(exercise.name) ×\(exercise.count)" : exercise.name)
                            .lineLimit(1)
                            .frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule()
                                    .fill(.orange)
                                    .frame(width: geo.size.width * CGFloat((value(exercise) ?? 0) / maxValue))
                            }
                        }
                        .frame(height: 10)
                        Text(label(exercise))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
