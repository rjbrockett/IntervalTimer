import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.sortOrder)
    private var templates: [WorkoutTemplate]

    @State private var selectedTemplate: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            if templates.isEmpty {
                emptyStateView
            } else {
                templateList
            }
        }
        .fullScreenCover(item: $selectedTemplate) { template in
            WorkoutSessionView(template: template)
        }
        .onAppear {
            if templates.isEmpty {
                seedSampleTemplates()
            }
        }
    }

    private func seedSampleTemplates() {
        // 1. Run/Walk with distance goals
        let runWalk = WorkoutTemplate(name: "Run/Walk 30min", sortOrder: 0, blocks: [
            IntervalBlock(name: "Warm Up", repeatCount: 1, sortOrder: 0, intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ]),
            IntervalBlock(name: "Intervals", repeatCount: 5, sortOrder: 1, intervals: [
                IntervalItem(name: "Run", duration: 180, sortOrder: 0, trackDistance: true, distanceGoal: 804.67),  // 0.5 mi
                IntervalItem(name: "Walk", duration: 90, sortOrder: 1)
            ]),
            IntervalBlock(name: "Cool Down", repeatCount: 1, sortOrder: 2, intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ])
        ])
        modelContext.insert(runWalk)

        // 2. 5K Training with distance goal
        let fiveK = WorkoutTemplate(name: "5K Training", sortOrder: 1, blocks: [
            IntervalBlock(name: "Warm Up", repeatCount: 1, sortOrder: 0, intervals: [
                IntervalItem(name: "Easy Jog", duration: 300, sortOrder: 0, trackDistance: true)
            ]),
            IntervalBlock(name: "Speed Work", repeatCount: 4, sortOrder: 1, intervals: [
                IntervalItem(name: "Fast Run", duration: 120, sortOrder: 0, trackDistance: true, distanceGoal: 804.67),  // 0.5 mi
                IntervalItem(name: "Recovery Jog", duration: 120, sortOrder: 1, trackDistance: true)
            ]),
            IntervalBlock(name: "Cool Down", repeatCount: 1, sortOrder: 2, intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ])
        ])
        modelContext.insert(fiveK)

        // 3. HIIT (with heart rate zones)
        let hiit = WorkoutTemplate(name: "HIIT 20min", sortOrder: 2, showHeartRateZones: true, blocks: [
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

        // 4. Tabata
        let tabata = WorkoutTemplate(name: "Tabata 4min", sortOrder: 3, blocks: [
            IntervalBlock(name: "Tabata", repeatCount: 8, sortOrder: 0, intervals: [
                IntervalItem(name: "Work", duration: 20, sortOrder: 0),
                IntervalItem(name: "Rest", duration: 10, sortOrder: 1)
            ])
        ])
        modelContext.insert(tabata)

        // 5. Pomodoro Study
        let pomodoro = WorkoutTemplate(name: "Pomodoro 25/5", sortOrder: 4, blocks: [
            IntervalBlock(name: "Study Sessions", repeatCount: 4, sortOrder: 0, intervals: [
                IntervalItem(name: "Focus", duration: 1500, sortOrder: 0),
                IntervalItem(name: "Break", duration: 300, sortOrder: 1)
            ])
        ])
        modelContext.insert(pomodoro)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Routines")
                .font(.headline)
            Text("Create routines on iPhone or Mac")
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
        .navigationTitle("Routines")
    }
}

#Preview {
    WatchContentView()
        .modelContainer(for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self])
}
