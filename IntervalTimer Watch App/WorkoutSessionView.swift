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
            // Primary metrics page
            VStack(spacing: 16) {
                // Elapsed time
                VStack(spacing: 4) {
                    Text("ELAPSED")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatElapsedTime(player.elapsedTotal))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Divider()

                // Current interval
                VStack(spacing: 4) {
                    Text("CURRENT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(player.currentStepName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                // Time remaining in current interval
                Text(formatTimeRemaining(player.currentStepTimeRemaining))
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .monospacedDigit()

                Divider()

                // Next interval
                VStack(spacing: 4) {
                    Text("NEXT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(player.nextStepName ?? "Last Step")
                        .font(.headline)
                        .foregroundStyle(player.nextStepName == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Divider()

                // Heart rate
                VStack(spacing: 4) {
                    Text("HEART RATE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(healthKit.currentHeartRate)")
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            // Secondary metrics page
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 4) {
                    Text("CALORIES")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(healthKit.activeEnergyBurned))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("KCAL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(spacing: 4) {
                    Text("INTERVAL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(player.currentStepIndex + 1) / \(player.totalSteps)")
                        .font(.title)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                Spacer()
            }
            .padding()
        }
        .tabViewStyle(.page)
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
