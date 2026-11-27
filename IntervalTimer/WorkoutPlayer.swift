import Foundation

/// A single flattened playback step
struct PlaybackStep: Identifiable, Equatable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let originalIntervalID: UUID
    let trackDistance: Bool
    let distanceGoal: Double?  // in meters
    var isRest: Bool = false
    /// Enclosing blocks, outermost first, with the repeat number for this step
    var context: [BlockContext] = []
    
    static func == (lhs: PlaybackStep, rhs: PlaybackStep) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class WorkoutPlayer {
    enum State {
        case running
        case paused
        case ended
    }
    
    /// Moments the UI should signal with sound/haptics
    enum Event {
        /// Seconds left in the current timed interval (3, 2, 1)
        case countdownTick(Int)
        /// A timed interval ran out and playback moved to the next one
        case intervalCompleted
        /// The final interval ran out
        case workoutCompleted
        /// The current step finished for any reason (fires before moving on)
        case stepEnded(StepEnd)
    }
    
    /// Details about a step as it finishes, for workout recording
    struct StepEnd {
        let step: PlaybackStep
        /// Active time spent in the step (pauses excluded)
        let elapsed: TimeInterval
        /// Active workout time when the step finished
        let workoutElapsed: TimeInterval
        let outcome: IntervalSplit.Outcome
    }
    
    private(set) var state: State = .running
    private(set) var elapsedTotal: TimeInterval = 0
    private(set) var currentStepIndex: Int = 0
    /// True once the final interval ran out (vs. the workout being ended early)
    private(set) var didComplete = false
    
    /// Called on the main thread when a feedback-worthy moment happens
    @ObservationIgnored var onEvent: ((Event) -> Void)?
    
    private var flattenedSteps: [PlaybackStep] = []
    
    // Timing state. While running, elapsed values are derived from these
    // start dates. On resume they're re-anchored so paused time is excluded.
    private var sessionStartTime: Date?
    private var timer: Timer?
    
    // Current step elapsed time
    private(set) var currentStepElapsed: TimeInterval = 0
    private var currentStepStartTime: Date?
    
    /// Last countdown second announced for the current step, to fire each tick once
    private var lastTickSecond: Int?
    
    /// - Parameter startPaused: Begin paused so the UI can run a lead-in
    ///   countdown before calling `resume()`.
    init(template: WorkoutTemplate, startPaused: Bool = false) {
        self.flattenedSteps = Self.flatten(template: template)
        let now = Date()
        self.sessionStartTime = now
        self.currentStepStartTime = now
        if startPaused {
            self.state = .paused
        }
        startTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Flattening Logic
    
    /// Flatten a WorkoutTemplate into a linear list of PlaybackSteps
    static func flatten(template: WorkoutTemplate) -> [PlaybackStep] {
        var steps: [PlaybackStep] = []
        let sortedBlocks = template.sortedBlocks
        for block in sortedBlocks {
            steps.append(contentsOf: flattenBlock(block))
        }
        return steps
    }
    
    /// Recursively flatten a single block (handles nesting and intermingled intervals/sub-blocks)
    private static func flattenBlock(_ block: IntervalBlock, context: [BlockContext] = []) -> [PlaybackStep] {
        var steps: [PlaybackStep] = []
        
        for repeatIndex in 0..<max(0, block.repeatCount) {
            let stepContext = context + [BlockContext(
                blockID: block.id,
                name: block.name,
                iteration: repeatIndex + 1,
                repeatCount: block.repeatCount
            )]
            for child in block.sortedChildren {
                switch child {
                case .interval(let interval):
                    let step = PlaybackStep(
                        id: UUID(),
                        name: interval.name,
                        duration: interval.duration,
                        originalIntervalID: interval.id,
                        trackDistance: interval.trackDistance,
                        distanceGoal: interval.distanceGoal,
                        isRest: interval.isRest,
                        context: stepContext
                    )
                    steps.append(step)
                case .childBlock(let childBlock):
                    steps.append(contentsOf: flattenBlock(childBlock, context: stepContext))
                }
            }
        }
        
        return steps
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard state == .running else { return }
        refreshElapsed()
        
        // Steps with duration 0 are untimed — only advanced manually via skipToNext()
        guard let currentStep = currentStep, currentStep.duration > 0 else { return }
        
        if currentStepElapsed >= currentStep.duration {
            // Auto-advance to next step when current step duration is exceeded
            autoAdvanceToNextStep()
        } else {
            announceCountdownTick(for: currentStep)
        }
    }
    
    /// Recompute elapsed values from the anchor dates
    private func refreshElapsed() {
        guard let sessionStart = sessionStartTime,
              let stepStart = currentStepStartTime else { return }
        let now = Date()
        elapsedTotal = now.timeIntervalSince(sessionStart)
        currentStepElapsed = now.timeIntervalSince(stepStart)
    }
    
    /// Fire a tick as the remaining time crosses 3, 2, and 1 seconds.
    /// Skips the second the step began in, so short steps don't tick
    /// on top of the previous interval's end signal.
    private func announceCountdownTick(for step: PlaybackStep) {
        let secondsLeft = Int((step.duration - currentStepElapsed).rounded(.up))
        let firstSecond = Int(step.duration.rounded(.up))
        guard (1...3).contains(secondsLeft),
              secondsLeft < firstSecond,
              secondsLeft != lastTickSecond else { return }
        lastTickSecond = secondsLeft
        onEvent?(.countdownTick(secondsLeft))
    }
    
    private func autoAdvanceToNextStep() {
        reportStepEnded(.completed)
        if currentStepIndex < flattenedSteps.count - 1 {
            currentStepIndex += 1
            restartCurrentStep()
            onEvent?(.intervalCompleted)
        } else {
            // Workout complete
            didComplete = true
            stop()
            onEvent?(.workoutCompleted)
        }
    }
    
    /// Notify listeners that the current step is finishing
    private func reportStepEnded(_ outcome: IntervalSplit.Outcome) {
        guard let step = currentStep else { return }
        // A timed step that ran out counts as exactly its duration
        // (the 0.1s timer can overshoot slightly)
        let elapsed = outcome == .completed && step.duration > 0
            ? step.duration
            : currentStepElapsed
        onEvent?(.stepEnded(StepEnd(
            step: step,
            elapsed: elapsed,
            workoutElapsed: elapsedTotal,
            outcome: outcome
        )))
    }
    
    /// Reset timing for the current step so it plays from the beginning
    private func restartCurrentStep() {
        currentStepStartTime = Date()
        currentStepElapsed = 0
        lastTickSecond = nil
    }
    
    // MARK: - Public Controls
    
    func pause() {
        guard state == .running else { return }
        // Capture exact elapsed values; they stay frozen while paused
        refreshElapsed()
        state = .paused
    }
    
    func resume() {
        guard state == .paused else { return }
        // Re-anchor start dates so the frozen elapsed values continue from
        // where they left off — paused time doesn't count toward the step
        let now = Date()
        sessionStartTime = now.addingTimeInterval(-elapsedTotal)
        currentStepStartTime = now.addingTimeInterval(-currentStepElapsed)
        state = .running
    }
    
    func skipToNext() {
        guard currentStepIndex < flattenedSteps.count - 1 else { return }
        if state == .running { refreshElapsed() }
        // Advancing a manual (untimed) interval is how it's meant to finish
        reportStepEnded(isCurrentStepUntimed ? .completed : .skipped)
        currentStepIndex += 1
        restartCurrentStep()
    }
    
    func skipToPrevious() {
        if state == .running { refreshElapsed() }
        reportStepEnded(.restarted)
        // If we're more than 3 seconds into current step (or on the first
        // step), restart it; otherwise go back to the previous step
        if currentStepElapsed <= 3.0 && currentStepIndex > 0 {
            currentStepIndex -= 1
        }
        restartCurrentStep()
    }
    
    /// End the workout early (user action)
    func end() {
        guard state != .ended else { return }
        if state == .running { refreshElapsed() }
        reportStepEnded(.endedEarly)
        stop()
    }
    
    private func stop() {
        state = .ended
        stopTimer()
    }
    
    // MARK: - Computed Properties
    
    var currentStep: PlaybackStep? {
        guard currentStepIndex < flattenedSteps.count else { return nil }
        return flattenedSteps[currentStepIndex]
    }
    
    var currentStepName: String {
        currentStep?.name ?? "No Step"
    }
    
    var nextStepName: String? {
        let nextIndex = currentStepIndex + 1
        guard nextIndex < flattenedSteps.count else { return nil }
        return flattenedSteps[nextIndex].name
    }
    
    var currentStepTimeRemaining: TimeInterval {
        guard let step = currentStep else { return 0 }
        if step.duration <= 0 { return 0 }
        return max(0, step.duration - currentStepElapsed)
    }

    /// Whether the current step is untimed (manual advance only)
    var isCurrentStepUntimed: Bool {
        guard let step = currentStep else { return false }
        return step.duration <= 0
    }
    
    var totalSteps: Int {
        flattenedSteps.count
    }
}
