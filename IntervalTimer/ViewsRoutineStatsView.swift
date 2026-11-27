import SwiftUI
import SwiftData

/// Every time one routine has been run, newest first
struct RoutineStatsView: View {
    let routineName: String
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]

    init(template: WorkoutTemplate) {
        routineName = template.name
        let templateID: UUID? = template.id
        _records = Query(
            filter: #Predicate<WorkoutRecord> { $0.templateID == templateID },
            sort: \WorkoutRecord.startedAt,
            order: .reverse
        )
    }

    private var completedCount: Int {
        records.filter { !$0.isPartial }.count
    }

    private var totalTime: TimeInterval {
        records.reduce(0) { $0 + $1.activeDuration }
    }

    /// Time-weighted across workouts that recorded heart rate
    private var averageHeartRate: Int? {
        let withHR = records.filter { $0.avgHeartRate != nil }
        let time = withHR.reduce(0) { $0 + $1.activeDuration }
        guard time > 0 else { return nil }
        let weighted = withHR.reduce(0.0) { $0 + Double($1.avgHeartRate ?? 0) * $1.activeDuration }
        return Int((weighted / time).rounded())
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "figure.run",
                    description: Text("Finish a workout of this routine to see its stats here.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                        summaryStat("Completed", "\(completedCount)")
                        summaryStat("Total Time", TimeFormatter.formatClock(totalTime))
                        summaryStat("Avg HR", averageHeartRate.map { "\($0)" } ?? "–")
                    }
                    .padding(.vertical, 4)
                }

                Section("Workouts") {
                    ForEach(records) { record in
                        NavigationLink(value: record) {
                            WorkoutRecordRow(record: record, showsRoutineName: false)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle(routineName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: WorkoutRecord.self) { record in
            WorkoutSummaryView(record: record)
        }
    }

    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
