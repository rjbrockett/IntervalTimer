import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var player: WorkoutPlayer
    @State private var showingEndConfirmation = false
    @State private var locationManager: LocationManager
    @State private var recorder: WorkoutRecorder
    /// Set when the workout ends and its report was saved; shows the summary
    @State private var finishedRecord: WorkoutRecord?
    /// Total distance at the moment the current step began (meters)
    @State private var stepStartDistance: Double = 0
    @State private var feedback = WorkoutFeedback()
    /// Number shown by the 3-2-1-GO lead-in (0 = "GO"), nil when hidden
    @State private var leadInCount: Int?
    @State private var leadInTask: Task<Void, Never>?
    
    /// Whether any interval in this template tracks distance
    private var anyIntervalTracksDistance: Bool {
        (template.blocks ?? []).contains { block in
            (block.intervals ?? []).contains { $0.trackDistance }
        }
    }
    
    /// Distance covered during the current interval only
    private var distanceMiles: Double {
        max(0, locationManager.totalDistance - stepStartDistance) / 1609.34
    }
    
    init(template: WorkoutTemplate) {
        self.template = template
        // Starts paused; the lead-in countdown resumes it
        self._player = State(initialValue: WorkoutPlayer(template: template, startPaused: true))
        // Created together so the recorder reads distance from this location manager
        let locationManager = LocationManager()
        self._locationManager = State(initialValue: locationManager)
        self._recorder = State(initialValue: WorkoutRecorder(
            sources: .init(distance: { locationManager.totalDistance }),
            tracksZones: false
        ))
    }
    
    var body: some View {
        if let record = finishedRecord {
            NavigationStack {
                WorkoutSummaryView(record: record)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        } else {
            workoutView
        }
    }
    
    private var workoutView: some View {
        VStack(spacing: 0) {
            // Top bar with elapsed time and end button
            topBar
            
            Divider()
            
            // Main content
            VStack(spacing: 24) {
                Spacer()
                
                // Current interval
                currentIntervalSection
                
                // Countdown timer
                countdownSection
                
                // Distance (if tracking)
                if player.currentStep?.trackDistance == true {
                    distanceSection
                }
                
                // Next up
                nextUpSection
                
                Spacer()
                
                // Controls
                controlsSection
                
                // Progress
                progressBar
            }
            .padding()
        }
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
        .overlay {
            // 3-2-1-GO lead-in
            if let count = leadInCount {
                leadInOverlay(count: count)
            }
        }
        .onAppear {
            if anyIntervalTracksDistance {
                locationManager.startTracking()
            }
            feedback.prepare()
            player.onEvent = { [feedback, recorder] event in
                feedback.handle(event)
                recorder.handle(event)
            }
            runLeadIn {
                player.resume()
                recorder.begin()
            }
        }
        .onDisappear {
            leadInTask?.cancel()
        }
        .onChange(of: player.state) { _, newState in
            if newState == .ended {
                finishWorkout()
            }
        }
        .onChange(of: player.currentStepIndex) {
            stepStartDistance = locationManager.totalDistance
        }
        .confirmationDialog("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End Workout", role: .destructive) {
                player.end()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatTime(player.elapsedTotal))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            
            Spacer()
            
            Button(role: .destructive) {
                showingEndConfirmation = true
            } label: {
                Text("End")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }
    
    // MARK: - Current Interval
    
    private var currentIntervalSection: some View {
        Text(player.currentStepName)
            .font(.system(.title, design: .rounded))
            .fontWeight(.bold)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Countdown
    
    private var countdownSection: some View {
        Group {
            if player.isCurrentStepUntimed {
                // Untimed: show elapsed time counting up
                Text(formatCountdown(player.currentStepElapsed))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                // Remaining time with the interval's total duration beside it
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    // Rounded up so "3, 2, 1" on screen line up with the tick signals
                    Text(formatCountdown(player.currentStepTimeRemaining.rounded(.up)))
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(countdownColor)
                        .contentTransition(.numericText())
                    Text("/" + formatCountdown(player.currentStep?.duration ?? 0))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }
    
    private var countdownColor: Color {
        let remaining = player.currentStepTimeRemaining
        if remaining <= 3 {
            return .red
        } else if remaining <= 10 {
            return .orange
        }
        return .primary
    }
    
    // MARK: - Distance
    
    private var distanceSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(.green)
            if let goal = player.currentStep?.distanceGoal, goal > 0 {
                let goalMiles = goal / 1609.34
                Text(String(format: "%.2f / %.2f mi", distanceMiles, goalMiles))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } else {
                Text(String(format: "%.2f mi", distanceMiles))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Next Up
    
    private var nextUpSection: some View {
        Group {
            if let nextName = player.nextStepName {
                HStack(spacing: 6) {
                    Text("NEXT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(nextName)
                        .font(.callout)
                        .fontWeight(.medium)
                }
            } else {
                Text("Last Interval")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        HStack(spacing: 32) {
            // Previous / Restart (long press to avoid accidental skips)
            HoldToActivateButton(
                systemImage: "backward.fill",
                label: "Previous",
                font: .title2,
                width: 56, height: 56
            ) {
                player.skipToPrevious()
                // Restarting or going back starts a fresh distance count
                stepStartDistance = locationManager.totalDistance
            }
            
            // Play / Pause
            Button {
                if player.state == .running {
                    player.pause()
                } else if player.state == .paused {
                    runLeadIn {
                        player.resume()
                    }
                }
            } label: {
                Image(systemName: player.state == .running ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.state == .running ? .orange : .green)
            
            // Next (long press to avoid accidental skips)
            HoldToActivateButton(
                systemImage: "forward.fill",
                label: "Next",
                font: .title2,
                width: 56, height: 56
            ) {
                player.skipToNext()
            }
        }
    }
    
    // MARK: - Finish
    
    /// Save the workout report and show the summary (or just close if the
    /// workout ended before it really started)
    private func finishWorkout() {
        // Build the record before stopTracking(), which resets the distance
        #if os(macOS)
        let deviceName = "Mac"
        #else
        let deviceName = "iPhone"
        #endif
        let record = recorder.makeRecord(
            template: template,
            deviceName: deviceName,
            activeDuration: player.elapsedTotal,
            isPartial: !player.didComplete
        )
        locationManager.stopTracking()
        feedback.finish()
        
        guard let record else {
            dismiss()
            return
        }
        modelContext.insert(record)
        try? modelContext.save()
        finishedRecord = record
    }
    
    // MARK: - Lead-In Countdown
    
    private func leadInOverlay(count: Int) -> some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            
            Text(count > 0 ? "\(count)" : "GO")
                .font(.system(size: 160, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? Color.primary : Color.green)
                .contentTransition(.numericText(countsDown: true))
        }
        .transition(.opacity)
        .accessibilityLabel(count > 0 ? "\(count)" : "Go")
    }
    
    /// Show 3-2-1-GO with a tick on each number, then run `onGo`
    private func runLeadIn(onGo: @escaping () -> Void) {
        guard leadInTask == nil else { return }
        leadInTask = Task { @MainActor in
            defer { leadInTask = nil }
            do {
                for count in [3, 2, 1] {
                    withAnimation(.snappy) { leadInCount = count }
                    feedback.countdownTick()
                    try await Task.sleep(for: .seconds(1))
                }
                withAnimation(.snappy) { leadInCount = 0 }
                feedback.go()
                onGo()
                try await Task.sleep(for: .seconds(0.6))
            } catch {
                // Cancelled (view went away) — fall through and hide
            }
            withAnimation { leadInCount = nil }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 6) {
            // Step progress
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        #if os(iOS)
                        .fill(Color(.systemGray5))
                        #else
                        .fill(Color(nsColor: .separatorColor))
                        #endif
                    
                    // Current step progress
                    if let step = player.currentStep, step.duration > 0 {
                        let fraction = min(1.0, player.currentStepElapsed / step.duration)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * fraction)
                    }
                }
            }
            .frame(height: 8)
            
            // Step counter
            Text("Step \(player.currentStepIndex + 1) of \(player.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Formatters
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(isPressing ? 0.4 : 0.2))
            )
            .scaleEffect(isPressing ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressing)
            .contentShape(RoundedRectangle(cornerRadius: 12))
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
                    repeatCount: 3,
                    sortOrder: 0,
                    intervals: [
                        IntervalItem(name: "Sprint", duration: 30, sortOrder: 0),
                        IntervalItem(name: "Rest", duration: 60, sortOrder: 1)
                    ]
                )
            ]
        )
    )
}
