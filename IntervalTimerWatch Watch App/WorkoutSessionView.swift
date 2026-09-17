import SwiftUI

struct WorkoutSessionView: View {
    let template: WorkoutTemplate
    @Binding var isPresented: Bool

    @State private var player: WorkoutPlayer
    @State private var healthKit = HealthKitManager()
    @State private var showingPauseOverlay = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingAuthError = false

    init(template: WorkoutTemplate, isPresented: Binding<Bool>) {
        self.template = template
        self._isPresented = isPresented
        self._player = State(initialValue: WorkoutPlayer(template: template))
    }

    var body: some View {
        ZStack {
            // Main workout display
            mainWorkoutView
                .gesture(swipeGesture)

            // Pause overlay
            if showingPauseOverlay {
                pauseOverlay
            }
        }
        .onAppear {
            startWorkout()
        }
        .onChange(of: player.state) { _, newState in
            if newState == .ended {
                endWorkout()
            }
        }
        .alert("HealthKit Not Authorized", isPresented: $showingAuthError) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("Please authorize HealthKit access in Settings to track your workout.")
        }
    }

    // MARK: - Main Workout View

    private var mainWorkoutView: some View {
        TabView {
            // Primary metrics page — scrollable
            ScrollView {
                VStack(spacing: 8) {
                    // Elapsed time
                    Text(formatElapsedTime(player.elapsedTotal))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.yellow)

                    // Current interval name + time remaining
                    VStack(spacing: 2) {
                        Text(player.currentStepName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(formatTimeRemaining(player.currentStepTimeRemaining))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }

                    Divider()

                    // Next interval
                    HStack {
                        Text("NEXT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(player.nextStepName ?? "Last Step")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(player.nextStepName == nil ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    Divider()

                    // Metrics row: heart rate + interval count
                    HStack(spacing: 16) {
                        // Heart rate
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("\(healthKit.currentHeartRate)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }

                        Divider()
                            .frame(height: 30)

                        // Interval count
                        VStack(spacing: 2) {
                            Text("STEP")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(player.currentStepIndex + 1)/\(player.totalSteps)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }

                    // Distance (conditional — based on current step's block setting)
                    if player.currentStep?.trackDistance == true {
                        Divider()
                        distanceView
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Secondary metrics page
            ScrollView {
                VStack(spacing: 12) {
                    // Calories
                    VStack(spacing: 2) {
                        Text("CALORIES")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(healthKit.activeEnergyBurned))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("KCAL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Heart rate detail
                    VStack(spacing: 2) {
                        Text("HEART RATE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(healthKit.currentHeartRate)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("BPM")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Distance detail (if any block tracks distance)
                    if anyBlockTracksDistance {
                        Divider()
                        VStack(spacing: 2) {
                            Text("DISTANCE")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            distanceDetailView
                        }
                    }

                    Divider()

                    // Elapsed time
                    VStack(spacing: 2) {
                        Text("ELAPSED")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatElapsedTime(player.elapsedTotal))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .tabViewStyle(.page)
    }

    // MARK: - Distance Views

    /// Whether any interval in this template has distance tracking enabled
    private var anyBlockTracksDistance: Bool {
        template.blocks.contains { block in
            block.intervals.contains { $0.trackDistance }
        }
    }

    /// The distance goal from the current step's block, if any
    private var currentDistanceGoal: Double? {
        player.currentStep?.distanceGoal
    }

    @ViewBuilder
    private var distanceView: some View {
        let miles = healthKit.distanceWalkingRunning / 1609.34
        VStack(spacing: 2) {
            Image(systemName: "figure.run")
                .font(.caption)
                .foregroundStyle(.green)
            if let goal = currentDistanceGoal, goal > 0 {
                let goalMiles = goal / 1609.34
                Text(String(format: "%.2f / %.2f mi", miles, goalMiles))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } else {
                Text(String(format: "%.2f mi", miles))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var distanceDetailView: some View {
        let miles = healthKit.distanceWalkingRunning / 1609.34
        // Use the first interval's goal that has one, for the detail view
        let goal = template.blocks
            .flatMap(\.intervals)
            .compactMap(\.distanceGoal)
            .first { $0 > 0 }
        if let goal {
            let goalMiles = goal / 1609.34
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", miles))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(String(format: "/ %.2f mi", goalMiles))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", miles))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("MI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("PAUSED")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)

                Divider()

                VStack(spacing: 12) {
                    Button(action: {
                        player.skipToPrevious()
                    }) {
                        Label("Previous", systemImage: "backward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        player.skipToNext()
                    }) {
                        Label("Next", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        player.resume()
                        healthKit.resumeWorkout()
                        withAnimation {
                            showingPauseOverlay = false
                        }
                    }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive, action: {
                        player.end()
                    }) {
                        Label("End Workout", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .gesture(resumeSwipeGesture)
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if value.translation.width > 50 && player.state == .running {
                    // Swipe right -> pause
                    player.pause()
                    healthKit.pauseWorkout()
                    withAnimation {
                        showingPauseOverlay = true
                    }
                }
                dragOffset = .zero
            }
    }

    private var resumeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width < -50 {
                    // Swipe left -> resume
                    player.resume()
                    healthKit.resumeWorkout()
                    withAnimation {
                        showingPauseOverlay = false
                    }
                }
            }
    }

    // MARK: - Workout Lifecycle

    private func startWorkout() {
        Task {
            do {
                if !healthKit.isAuthorized {
                    try await healthKit.requestAuthorization()
                }
                try healthKit.startWorkout()
            } catch {
                showingAuthError = true
            }
        }
    }

    private func endWorkout() {
        Task {
            do {
                try await healthKit.endWorkout()
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                print("Failed to end workout: \(error)")
                await MainActor.run {
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Formatters

    private func formatElapsedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        } else {
            return String(format: "%d", secs)
        }
    }
}

#Preview {
    WorkoutSessionView(
        template: WorkoutTemplate(
            name: "Test Workout",
            blocks: [
                IntervalBlock(
                    name: "Main",
                    repeatCount: 2,
                    sortOrder: 0,
                    intervals: [
                        IntervalItem(name: "Sprint", duration: 30, sortOrder: 0),
                        IntervalItem(name: "Rest", duration: 30, sortOrder: 1)
                    ]
                )
            ]
        ),
        isPresented: .constant(true)
    )
}
