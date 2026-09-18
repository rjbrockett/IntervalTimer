import SwiftUI

struct WorkoutSessionView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var player: WorkoutPlayer
    @State private var healthKit = HealthKitManager()
    @State private var showingPauseOverlay = false
    @State private var showingAuthError = false

    init(template: WorkoutTemplate) {
        self.template = template
        self._player = State(initialValue: WorkoutPlayer(template: template))
    }

    /// The background color based on current heart rate zone
    private var zoneBackgroundColor: Color {
        guard template.showHeartRateZones,
              let zone = healthKit.currentHeartRateZone else {
            return .clear
        }
        let c = zone.color
        return Color(red: c.red, green: c.green, blue: c.blue).opacity(0.3)
    }

    var body: some View {
        ZStack {
            // Heart rate zone background
            if template.showHeartRateZones {
                zoneBackgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: healthKit.currentHeartRateZone?.rawValue)
            }

            // Main workout display
            mainWorkoutView

            // Pause overlay
            if showingPauseOverlay {
                pauseOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                dismiss()
            }
        } message: {
            Text("Please authorize HealthKit access in Settings to track your workout.")
        }
    }

    // MARK: - Main Workout View

    private var mainWorkoutView: some View {
        TabView {
            // Primary metrics page
            VStack(spacing: 2) {
                // Heart rate zone label (top-left)
                if template.showHeartRateZones {
                    HStack {
                        if let zone = healthKit.currentHeartRateZone {
                            Text(zone.name.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        } else {
                            Text("—")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                }

                // Current interval name
                Text(player.currentStepName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Countdown timer
                Text(formatTimeRemaining(player.currentStepTimeRemaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(countdownColor)

                // Distance (conditional)
                if player.currentStep?.trackDistance == true {
                    distanceView
                }

                // Info row: heart rate | elapsed | step counter
                HStack(spacing: 8) {
                    // Heart rate
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                        Text("\(healthKit.currentHeartRate)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }

                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    // Elapsed time
                    Text(formatElapsedTime(player.elapsedTotal))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.yellow)

                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    // Step counter
                    Text("\(player.currentStepIndex + 1)/\(player.totalSteps)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Next interval
                HStack(spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(player.nextStepName ?? "Last Step")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(player.nextStepName == nil ? .secondary : .primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Control buttons
                controlButtons
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 4)

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

                    Divider()

                    // Total distance
                    VStack(spacing: 2) {
                        Text("DISTANCE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", healthKit.distanceWalkingRunning / 1609.34))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("MI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 12) {
            // Previous
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            // Play / Pause
            Button {
                if player.state == .running {
                    player.pause()
                    healthKit.pauseWorkout()
                    withAnimation {
                        showingPauseOverlay = true
                    }
                } else if player.state == .paused {
                    player.resume()
                    healthKit.resumeWorkout()
                    withAnimation {
                        showingPauseOverlay = false
                    }
                }
            } label: {
                Image(systemName: player.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.state == .running ? .orange : .green)

            // Next
            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    // MARK: - Countdown Color

    private var countdownColor: Color {
        let remaining = player.currentStepTimeRemaining
        if remaining <= 3 {
            return .red
        } else if remaining <= 10 {
            return .orange
        }
        return .orange
    }

    // MARK: - Distance Views

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

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)

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
            .padding()
        }
        .gesture(resumeSwipeGesture)
    }

    // MARK: - Gestures

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
                    dismiss()
                }
            } catch {
                print("Failed to end workout: \(error)")
                await MainActor.run {
                    dismiss()
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
        )
    )
}
