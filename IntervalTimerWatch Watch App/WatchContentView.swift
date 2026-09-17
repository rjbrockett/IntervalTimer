import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    @State private var selectedTemplate: WorkoutTemplate?
    @State private var isWorkoutActive = false

    var body: some View {
        NavigationStack {
            if templates.isEmpty {
                emptyStateView
            } else {
                templateList
            }
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutSessionView(template: template, isPresented: $isWorkoutActive)
        }
        .onAppear {
            if templates.isEmpty {
                seedSampleTemplates()
            }
        }
    }

    private func seedSampleTemplates() {
        // Basic Run/Walk (intervals block tracks distance with 3mi goal)
        let runWalk = WorkoutTemplate(name: "Run/Walk 30min", blocks: [
            IntervalBlock(name: "Warm Up", repeatCount: 1, sortOrder: 0, intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ]),
            IntervalBlock(name: "Intervals", repeatCount: 5, sortOrder: 1, intervals: [
                IntervalItem(name: "Run", duration: 180, sortOrder: 0, trackDistance: true, distanceGoal: 4828.03),  // 3 miles
                IntervalItem(name: "Walk", duration: 90, sortOrder: 1, trackDistance: true)
            ]),
            IntervalBlock(name: "Cool Down", repeatCount: 1, sortOrder: 2, intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ])
        ])
        modelContext.insert(runWalk)

        // HIIT
        let hiit = WorkoutTemplate(name: "HIIT 20min", blocks: [
            IntervalBlock(name: "Warm Up", repeatCount: 1, sortOrder: 0, intervals: [
                IntervalItem(name: "Light Jog", duration: 180, sortOrder: 0)
            ]),
            IntervalBlock(name: "HIIT", repeatCount: 8, sortOrder: 1, intervals: [
                IntervalItem(name: "Sprint", duration: 30, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 90, sortOrder: 1)
            ]),
            IntervalBlock(name: "Cool Down", repeatCount: 1, sortOrder: 2, intervals: [
                IntervalItem(name: "Walk", duration: 180, sortOrder: 0)
            ])
        ])
        modelContext.insert(hiit)

        // Tabata
        let tabata = WorkoutTemplate(name: "Tabata 4min", blocks: [
            IntervalBlock(name: "Tabata", repeatCount: 8, sortOrder: 0, intervals: [
                IntervalItem(name: "Work", duration: 20, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 10, sortOrder: 1)
            ])
        ])
        modelContext.insert(tabata)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Templates")
                .font(.headline)
            Text("Create templates on iPhone or Mac")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                Button(action: {
                    selectedTemplate = template
                    isWorkoutActive = true
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text("\(template.blocks.count) block\(template.blocks.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Workouts")
    }
}

#Preview {
    WatchContentView()
        .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
}
