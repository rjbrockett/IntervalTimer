import SwiftUI
import SwiftData

struct WatchContentView: View {
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
