import SwiftUI

struct WorkoutSessionView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var player: WorkoutPlayer
    @State private var healthKit = HealthKitManager()
    @State private var showingPauseOverlay = false
    @State private var showingAuthError = false
    /// Total distance at the moment the current step began (meters)
    @State private var stepStartDistance: Double = 0
    /// Number shown by the 3-2-1-GO lead-in (0 = "GO"), nil when hidden
    @State private var leadInCount: Int?
    @State private var leadInTask: Task<Void, Never>?

    init(template: WorkoutTemplate) {
        self.template = template
        // Starts paused; the lead-in countdown resumes it
        self._player = State(initialValue: WorkoutPlayer(template: template, startPaused: true))
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

            // 3-2-1-GO lead-in
            if let count = leadInCount {
                leadInOverlay(count: count)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            player.onEvent = { WorkoutFeedback.handle($0) }
            startWorkout()
        }
        .onDisappear {
            leadInTask?.cancel()
        }
        .onChange(of: player.state) { _, newState in
            if newState == .ended {
                endWorkout()
            }
        }
        .onChange(of: player.currentStepIndex) {
            stepStartDistance = healthKit.distanceWalkingRunning
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

                // Countdown timer (or elapsed time for untimed steps)
                if player.isCurrentStepUntimed {
                    Text(formatTimeRemaining(player.currentStepElapsed))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    // Remaining time with the interval's total duration beside it
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        // Rounded up so "3, 2, 1" on screen line up with the tick signals
                        Text(formatTimeRemaining(player.currentStepTimeRemaining.rounded(.up)))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(countdownColor)
                        Text("/" + formatTimeRemaining(player.currentStep?.duration ?? 0))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }

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
            // Previous (long press to avoid accidental skips)
            HoldToActivateButton(
                systemImage: "backward.fill",
                label: "Previous",
                font: .system(size: 14),
                width: 36, height: 36
            ) {
                player.skipToPrevious()
                // Restarting or going back starts a fresh distance count
                stepStartDistance = healthKit.distanceWalkingRunning
            }

            // Play / Pause
            Button {
                if player.state == .running {
                    player.pause()
                    healthKit.pauseWorkout()
                    withAnimation {
                        showingPauseOverlay = true
                    }
                } else if player.state == .paused {
                    resumeWithLeadIn()
                }
            } label: {
                Image(systemName: player.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.state == .running ? .orange : .green)

            // Next (long press to avoid accidental skips)
            HoldToActivateButton(
                systemImage: "forward.fill",
                label: "Next",
                font: .system(size: 14),
                width: 36, height: 36
            ) {
                player.skipToNext()
            }
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
        // Distance covered during the current interval only
        let miles = max(0, healthKit.distanceWalkingRunning - stepStartDistance) / 1609.34
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
                    resumeWithLeadIn()
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
                    resumeWithLeadIn()
                }
            }
    }

    // MARK: - Lead-In Countdown

    private func leadInOverlay(count: Int) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Text(count > 0 ? "\(count)" : "GO")
                .font(.system(size: count > 0 ? 90 : 60, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? Color.white : Color.green)
                .contentTransition(.numericText(countsDown: true))
        }
        .transition(.opacity)
        .accessibilityLabel(count > 0 ? "\(count)" : "Go")
    }

    /// Show 3-2-1-GO with a tap on each number, then run `onGo`
    private func runLeadIn(onGo: @escaping () -> Void) {
        guard leadInTask == nil else { return }
        leadInTask = Task { @MainActor in
            defer { leadInTask = nil }
            do {
                for count in [3, 2, 1] {
                    withAnimation(.snappy) { leadInCount = count }
                    WorkoutFeedback.countdownTick()
                    try await Task.sleep(for: .seconds(1))
                }
                withAnimation(.snappy) { leadInCount = 0 }
                WorkoutFeedback.go()
                onGo()
                try await Task.sleep(for: .seconds(0.6))
            } catch {
                // Cancelled (view went away) — fall through and hide
            }
            withAnimation { leadInCount = nil }
        }
    }

    private func resumeWithLeadIn() {
        guard player.state == .paused else { return }
        withAnimation {
            showingPauseOverlay = false
        }
        runLeadIn {
            player.resume()
            healthKit.resumeWorkout()
        }
    }

    // MARK: - Workout Lifecycle

    private func startWorkout() {
        Task {
            do {
                if !healthKit.isAuthorized {
                    try await healthKit.requestAuthorization()
                }
            } catch {
                showingAuthError = true
                return
            }
            // Start the HealthKit session and timer together on "GO"
            runLeadIn {
                do {
                    try healthKit.startWorkout()
                    player.resume()
                } catch {
                    showingAuthError = true
                }
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

// MARK: - Hold To Activate Button

/// A control that only fires after a long press, so a mistimed tap
/// (e.g. while reaching for pause) doesn't skip an interval.
private struct HoldToActivateButton: View {
    let systemImage: String
    let label: String
    let font: Font
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    @State private var isPressing = false
    @State private var activationCount = 0

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .foregroundStyle(.secondary)
            .frame(width: width, height: height)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(isPressing ? 0.4 : 0.2))
            )
            .scaleEffect(isPressing ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressing)
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: 0.5) {
                activationCount += 1
                action()
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
            .sensoryFeedback(.impact, trigger: activationCount)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityHint("Press and hold")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
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
