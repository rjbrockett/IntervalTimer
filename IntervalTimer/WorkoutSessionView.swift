import SwiftUI

struct WorkoutSessionView: View {
    let template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss
    
    @State private var player: WorkoutPlayer
    @State private var showingEndConfirmation = false
    
    init(template: WorkoutTemplate) {
        self.template = template
        self._player = State(initialValue: WorkoutPlayer(template: template))
    }
    
    var body: some View {
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
        .background(Color(.systemBackground))
        .onChange(of: player.state) { _, newState in
            if newState == .ended {
                dismiss()
            }
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
        Text(formatCountdown(player.currentStepTimeRemaining))
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(countdownColor)
            .contentTransition(.numericText())
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
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .foregroundStyle(.green)
                if let goal = player.currentStep?.distanceGoal, goal > 0 {
                    let goalMiles = goal / 1609.34
                    Text(String(format: "Goal: %.2f mi", goalMiles))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Distance Tracking")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
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
            // Previous / Restart
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            
            // Play / Pause
            Button {
                if player.state == .running {
                    player.pause()
                } else if player.state == .paused {
                    player.resume()
                }
            } label: {
                Image(systemName: player.state == .running ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 72, height: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.state == .running ? .orange : .green)
            
            // Next
            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
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
                        .fill(Color(.systemGray5))
                    
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
