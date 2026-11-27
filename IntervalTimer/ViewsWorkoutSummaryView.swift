import SwiftUI
import Charts

/// Post-workout report: headline stats, heart rate chart, zones, and a link
/// to the per-interval breakdown. Shown after a workout and from history.
struct WorkoutSummaryView: View {
    let record: WorkoutRecord
    private let report: WorkoutReport
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    /// Rendered image of the summary for the share button
    @State private var shareImage: Image?

    init(record: WorkoutRecord) {
        self.record = record
        self.report = WorkoutReport(record: record)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                WorkoutSummaryOverview(record: record, report: report)

                if !report.splits.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("By Interval")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        NavigationLink {
                            WorkoutIntervalsView(record: record, report: report)
                        } label: {
                            Text("See all \(report.splits.count)")
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(ReportFormat.groupedBackground)
        .navigationTitle("Summary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(record.routineName, image: shareImage)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: colorScheme) {
            shareImage = renderShareImage()
        }
    }

    /// Render the overview (header, stats, chart, zones) as a standalone image
    @MainActor
    private func renderShareImage() -> Image? {
        let card = WorkoutSummaryOverview(record: record, report: report)
            .padding(20)
            .frame(width: 390)
            .background(ReportFormat.groupedBackground)
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = displayScale
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: displayScale)
    }
}

/// Header, stat cards, heart rate chart and zones. Separate from the scroll
/// view so it can also be rendered as a shareable image.
struct WorkoutSummaryOverview: View {
    let record: WorkoutRecord
    let report: WorkoutReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statCards
            if record.hasHeartRate, report.samples.count >= 2 {
                HeartRateChartCard(record: record, report: report)
            }
            if let zones = record.zoneSeconds {
                HeartRateZonesCard(zoneSeconds: zones)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.routineName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                Text([ReportFormat.timeRange(record), record.deviceName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .foregroundStyle(.secondary)
                if record.isPartial {
                    Text("Partial")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
        }
        .padding(.bottom, 4)
    }

    private var statCards: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatCard(title: "Total Time", value: TimeFormatter.formatClock(record.activeDuration), unit: nil, color: .primary)
            if let avg = record.avgHeartRate {
                StatCard(title: "Avg Heart Rate", value: "\(avg)", unit: "BPM", color: .red)
            }
            if let max = record.maxHeartRate {
                StatCard(title: "Max Heart Rate", value: "\(max)", unit: "BPM", color: .red)
            }
            if let calories = record.activeCalories {
                StatCard(title: "Active Calories", value: "\(Int(calories.rounded()))", unit: "KCAL", color: .orange)
            }
            if let distance = record.totalDistance {
                StatCard(title: "Distance", value: String(format: "%.2f", distance / 1609.34), unit: "MI", color: .green)
            }
        }
    }
}

// MARK: - Cards

struct StatCard: View {
    let title: String
    let value: String
    let unit: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color == .primary ? Color.secondary : color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Heart rate line over time with work intervals shaded behind it
struct HeartRateChartCard: View {
    let record: WorkoutRecord
    let report: WorkoutReport

    private var bpmRange: ClosedRange<Int> {
        let values = report.samples.map(\.bpm)
        return (values.min() ?? 0)...(values.max() ?? 0)
    }

    /// Y axis padded and rounded to tens so the line isn't flush with the edges
    private var yDomain: ClosedRange<Int> {
        let lower = max(0, (bpmRange.lowerBound - 5) / 10 * 10)
        let upper = (bpmRange.upperBound + 14) / 10 * 10
        return lower...upper
    }

    private var workSplits: [IntervalSplit] {
        report.splits.filter { !$0.isRest }
    }

    /// Round labels only when there's room for them
    private var labeledRounds: [WorkoutReport.Round] {
        report.rounds.count > 1 && report.rounds.count <= 6 ? report.rounds : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heart Rate")
                    .font(.headline)
                Spacer()
                Text("\(bpmRange.lowerBound)–\(bpmRange.upperBound) BPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(workSplits) { split in
                    RectangleMark(
                        xStart: .value("Start", split.startOffset),
                        xEnd: .value("End", split.startOffset + split.actualDuration),
                        yStart: .value("Low", yDomain.lowerBound),
                        yEnd: .value("High", yDomain.upperBound)
                    )
                    .foregroundStyle(Color.orange.opacity(0.18))
                }
                ForEach(report.rounds.dropFirst()) { round in
                    RuleMark(x: .value("Round", round.startOffset))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                ForEach(report.samples, id: \.offset) { sample in
                    LineMark(
                        x: .value("Time", sample.offset),
                        y: .value("BPM", sample.bpm)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYScale(domain: yDomain)
            .chartXScale(domain: 0...max(1, record.activeDuration))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                if labeledRounds.isEmpty {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(TimeFormatter.formatClock(seconds))
                            }
                        }
                    }
                } else {
                    AxisMarks(values: labeledRounds.map { $0.startOffset + $0.duration / 2 }) { value in
                        AxisValueLabel {
                            Text(labeledRounds[value.index].shortTitle)
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Heart rate chart, \(bpmRange.lowerBound) to \(bpmRange.upperBound) BPM")

            legend
        }
        .padding(14)
        .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var legend: some View {
        var names: [String] = []
        for name in workSplits.map(\.name) where !names.contains(name) {
            names.append(name)
        }
        let workLabel = names.isEmpty ? "Work" : "Work (\(names.prefix(3).joined(separator: ", "))\(names.count > 3 ? "…" : ""))"
        return HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orange.opacity(0.25))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.orange.opacity(0.5)))
                    .frame(width: 12, height: 12)
                Text(workLabel)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.secondary.opacity(0.5))
                    .frame(width: 12, height: 12)
                Text("Rest")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Stacked bar of time spent in each heart rate zone
struct HeartRateZonesCard: View {
    let zoneSeconds: [Int]

    private var total: Int { max(1, zoneSeconds.reduce(0, +)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heart Rate Zones")
                    .font(.headline)
                Spacer()
                Text("Time in zone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(HeartRateZone.allCases, id: \.self) { zone in
                        let seconds = seconds(in: zone)
                        if seconds > 0 {
                            ReportFormat.zoneColor(zone)
                                .frame(width: max(2, geo.size.width * CGFloat(seconds) / CGFloat(total)))
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)

            HStack(alignment: .top, spacing: 0) {
                ForEach(HeartRateZone.allCases, id: \.self) { zone in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ReportFormat.zoneColor(zone))
                                .frame(width: 7, height: 7)
                            Text(zone.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Text(TimeFormatter.formatClock(TimeInterval(seconds(in: zone))))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(14)
        .background(ReportFormat.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func seconds(in zone: HeartRateZone) -> Int {
        let index = zone.rawValue - 1
        return index < zoneSeconds.count ? zoneSeconds[index] : 0
    }
}

#Preview("Summary — Apple Watch") {
    NavigationStack {
        WorkoutSummaryView(record: .previewHIIT())
    }
}

#Preview("Summary — iPhone (no HR)") {
    NavigationStack {
        WorkoutSummaryView(record: .previewHIIT(withHeartRate: false))
    }
}

// MARK: - Platform colors

extension ReportFormat {
    static var groupedBackground: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
