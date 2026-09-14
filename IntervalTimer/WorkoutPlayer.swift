import Foundation

/// A single flattened playback step
struct PlaybackStep: Identifiable, Equatable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let originalIntervalID: UUID
    
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
    
    private(set) var state: State = .running
    private(set) var elapsedTotal: TimeInterval = 0
    private(set) var currentStepIndex: Int = 0
    
    private var flattenedSteps: [PlaybackStep] = []
    
    // Timing state
    private var sessionStartTime: Date?
    private var lastResumeTime: Date?
    private var accumulatedPausedDuration: TimeInterval = 0
    private var timer: Timer?
    
    // Current step elapsed time
    private(set) var currentStepElapsed: TimeInterval = 0
    private var currentStepStartTime: Date?
    
    init(template: WorkoutTemplate) {
        self.flattenedSteps = Self.flatten(template: template)
        self.sessionStartTime = Date()
        self.lastResumeTime = Date()
        self.currentStepStartTime = Date()
        startTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Flattening Logic
    
    /// Flatten a WorkoutTemplate into a linear list of PlaybackSteps
    static func flatten(template: WorkoutTemplate) -> [PlaybackStep] {
        var steps: [PlaybackStep] = []
        let sortedBlocks = template.blocks.sorted { $0.sortOrder < $1.sortOrder }
        for block in sortedBlocks {
            steps.append(contentsOf: flattenBlock(block))
        }
        return steps
    }
    
    /// Recursively flatten a single block (handles nesting)
    private static func flattenBlock(_ block: IntervalBlock) -> [PlaybackStep] {
        var steps: [PlaybackStep] = []
        
        for _ in 0..<block.repeatCount {
            if !block.childBlocks.isEmpty {
                // Group block: recurse into sorted child blocks
                let sortedChildren = block.childBlocks.sorted { $0.sortOrder < $1.sortOrder }
                for child in sortedChildren {
                    steps.append(contentsOf: flattenBlock(child))
                }
            } else {
                // Leaf block: iterate its intervals
                let sortedIntervals = block.intervals.sorted { $0.sortOrder < $1.sortOrder }
                for interval in sortedIntervals {
                    let step = PlaybackStep(
                        id: UUID(),
                        name: interval.name,
                        duration: interval.duration,
                        originalIntervalID: interval.id
                    )
                    steps.append(step)
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
        guard state == .running,
              let sessionStart = sessionStartTime,
              lastResumeTime != nil,
              let stepStart = currentStepStartTime else {
            return
        }
        
        let now = Date()
        elapsedTotal = now.timeIntervalSince(sessionStart) - accumulatedPausedDuration
        currentStepElapsed = now.timeIntervalSince(stepStart)
        
        // Auto-advance to next step if current step duration is exceeded
        if let currentStep = currentStep, currentStepElapsed >= currentStep.duration {
            autoAdvanceToNextStep()
        }
    }
    
    private func autoAdvanceToNextStep() {
        if currentStepIndex < flattenedSteps.count - 1 {
            currentStepIndex += 1
            currentStepStartTime = Date()
            currentStepElapsed = 0
        } else {
            // Workout complete
            end()
        }
    }
    
    // MARK: - Public Controls
    
    func pause() {
        guard state == .running else { return }
        state = .paused
        
        // Track when we paused for accurate elapsed time calculation
        lastResumeTime = nil
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .running
        
        // Calculate how long we were paused and add it to accumulated pause duration
        let now = Date()
        if let lastResume = lastResumeTime {
            // This shouldn't happen, but safe guard
            accumulatedPausedDuration += now.timeIntervalSince(lastResume)
        } else if let sessionStart = sessionStartTime {
            let totalElapsedSinceStart = now.timeIntervalSince(sessionStart)
            accumulatedPausedDuration = totalElapsedSinceStart - elapsedTotal
        }
        
        lastResumeTime = now
    }
    
    func skipToNext() {
        guard currentStepIndex < flattenedSteps.count - 1 else { return }
        currentStepIndex += 1
        currentStepStartTime = Date()
        currentStepElapsed = 0
    }
    
    func skipToPrevious() {
        // If we're more than 3 seconds into current step, restart it
        if currentStepElapsed > 3.0 {
            currentStepStartTime = Date()
            currentStepElapsed = 0
        } else if currentStepIndex > 0 {
            // Otherwise go to previous step
            currentStepIndex -= 1
            currentStepStartTime = Date()
            currentStepElapsed = 0
        } else {
            // At first step, just restart it
            currentStepStartTime = Date()
            currentStepElapsed = 0
        }
    }
    
    func end() {
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
        return max(0, step.duration - currentStepElapsed)
    }
    
    var totalSteps: Int {
        flattenedSteps.count
    }
}
