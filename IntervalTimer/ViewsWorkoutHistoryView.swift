import SwiftUI
import SwiftData

/// All workout reports, newest first, grouped by month
struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse)
    private var records: [WorkoutRecord]

    /// Consecutive records grouped by month (records are already newest first)
    private var months: [(title: String, records: [WorkoutRecord])] {
        var groups: [(title: String, records: [WorkoutRecord])] = []
        for record in records {
            let title = record.startedAt?.formatted(.dateTime.month(.wide).year()) ?? "Unknown Date"
            if groups.last?.title == title {
                groups[groups.count - 1].records.append(record)
            } else {
                groups.append((title, [record]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(months, id: \.title) { month in
                    Section(month.title) {
                        ForEach(month.records) { record in
                            NavigationLink(value: record) {
                                WorkoutRecordRow(record: record)
                            }
                        }
                        .onDelete { offsets in
                            delete(offsets.map { month.records[$0] })
                        }
                    }
                }
            }
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Workouts you finish on your iPhone or Apple Watch will appear here.")
                    )
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutRecord.self) { record in
                WorkoutSummaryView(record: record)
            }
        }
    }

    private func delete(_ toDelete: [WorkoutRecord]) {
        for record in toDelete {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}
