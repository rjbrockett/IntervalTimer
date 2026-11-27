import Foundation

/// Collects what happens during a workout and turns it into a `WorkoutRecord`.
///
/// Platform-agnostic (shared by iPhone and watch): live metrics come in through
/// closures, so the watch can feed HealthKit values and the iPhone GPS distance.
/// Step boundaries come from `WorkoutPlayer.Event.stepEnded`.
final class WorkoutRecorder {
    /// Live metric sources. Return nil when a metric isn't available.
    struct Sources {
        /// Total distance so far (meters)
        var distance: () -> Double? = { nil }
        /// Current heart rate (BPM)
        var heartRate: () -> Int? = { nil }
        /// Active calories so far (kcal)
        var calories: () -> Double? = { nil }
        /// Max heart rate for zone calculation (0 = unknown)
        var maxHeartRate: () -> Int = { 0 }
    }

    /// One heart-rate point is kept in the stored series every this many seconds
    static let seriesInterval = 5

    private let sources: Sources
    /// Whether to track time in each heart rate zone
    private let tracksZones: Bool

    private(set) var startedAt: Date?
    private(set) var splits: [IntervalSplit] = []
    private(set) var heartRateSeries: [HeartRateSample] = []
    private(set) var zoneSeconds = [Int](repeating: 0, count: HeartRateZone.allCases.count)

    // Whole-workout heart rate (one reading per second)
    private var heartRateSum = 0
    private var heartRateCount = 0
    private var heartRatePeak = 0

    // Current step accumulators
    private var stepStartDistance: Double = 0
    private var stepStartHeartRate: Int?
    private var stepHeartRateSum = 0
    private var stepHeartRateCount = 0
    private var stepHeartRatePeak = 0

    private var sampleTimer: Timer?

    init(sources: Sources, tracksZones: Bool) {
        self.sources = sources
        self.tracksZones = tracksZones
    }

    deinit {
        sampleTimer?.invalidate()
    }

    // MARK: - Lifecycle

    /// Call when the workout actually starts (on "GO")
    func begin(at date: Date = Date()) {
        startedAt = date
        beginStep()
    }

    /// Sample heart rate once per second while `isRunning` returns true.
    /// `activeElapsed` supplies workout time excluding pauses.
    func startSampling(isRunning: @escaping () -> Bool, activeElapsed: @escaping () -> TimeInterval) {
        sampleTimer?.invalidate()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, isRunning(), let bpm = self.sources.heartRate(), bpm > 0 else { return }
            self.recordHeartRate(bpm, at: activeElapsed())
        }
    }

    func stopSampling() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }

    /// Forward player events here
    func handle(_ event: WorkoutPlayer.Event) {
        if case .stepEnded(let end) = event {
            recordStep(end)
        }
    }

    // MARK: - Recording

    /// Add one per-second heart rate reading
    func recordHeartRate(_ bpm: Int, at offset: TimeInterval) {
        heartRateSum += bpm
        heartRateCount += 1
        heartRatePeak = max(heartRatePeak, bpm)

        stepHeartRateSum += bpm
        stepHeartRateCount += 1
        stepHeartRatePeak = max(stepHeartRatePeak, bpm)

        if heartRateCount % Self.seriesInterval == 1 {
            heartRateSeries.append(HeartRateSample(offset: offset, bpm: bpm))
        }

        if tracksZones, let zone = HeartRateZone.from(bpm: bpm, maxHeartRate: sources.maxHeartRate()) {
            zoneSeconds[zone.rawValue - 1] += 1
        }
    }

    /// Turn a finished step into a split, then start tracking the next one
    func recordStep(_ end: WorkoutPlayer.StepEnd) {
        defer { beginStep() }

        // A restart or early end within the first second isn't a real attempt
        // (e.g. tapping back twice to reach an earlier interval)
        if end.elapsed < 1, end.outcome == .restarted || end.outcome == .endedEarly {
            return
        }

        let step = end.step
        let distance: Double? = step.trackDistance
            ? max(0, (sources.distance() ?? 0) - stepStartDistance)
            : nil

        var recovered: Int?
        if step.isRest, let startHR = stepStartHeartRate, let endHR = sources.heartRate(), endHR > 0 {
            recovered = startHR - endHR
        }

        splits.append(IntervalSplit(
            intervalID: step.originalIntervalID,
            name: step.name,
            isRest: step.isRest,
            plannedDuration: step.duration,
            actualDuration: end.elapsed,
            startOffset: max(0, end.workoutElapsed - end.elapsed),
            distance: distance,
            distanceGoal: step.distanceGoal,
            outcome: end.outcome,
            avgHeartRate: stepHeartRateCount > 0 ? stepHeartRateSum / stepHeartRateCount : nil,
            peakHeartRate: stepHeartRateCount > 0 ? stepHeartRatePeak : nil,
            recoveredBPM: recovered,
            context: step.context
        ))
    }

    private func beginStep() {
        stepStartDistance = sources.distance() ?? 0
        stepStartHeartRate = sources.heartRate().flatMap { $0 > 0 ? $0 : nil }
        stepHeartRateSum = 0
        stepHeartRateCount = 0
        stepHeartRatePeak = 0
    }

    // MARK: - Output

    /// Build the record to save. Returns nil if the workout never really
    /// started (ended during the lead-in countdown).
    func makeRecord(template: WorkoutTemplate,
                    deviceName: String,
                    activeDuration: TimeInterval,
                    isPartial: Bool,
                    endedAt: Date = Date()) -> WorkoutRecord? {
        stopSampling()
        guard let startedAt, activeDuration >= 1 else { return nil }

        let record = WorkoutRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            deviceName: deviceName,
            isPartial: isPartial,
            templateID: template.id,
            originalTemplateID: template.originalTemplateID ?? template.id,
            routineName: template.name,
            activeDuration: activeDuration
        )
        record.totalDistance = sources.distance().flatMap { $0 > 0 ? $0 : nil }
        record.activeCalories = sources.calories().flatMap { $0 > 0 ? $0 : nil }
        if heartRateCount > 0 {
            record.avgHeartRate = heartRateSum / heartRateCount
            record.maxHeartRate = heartRatePeak
            record.heartRateSamples = heartRateSeries
            if tracksZones, zoneSeconds.contains(where: { $0 > 0 }) {
                record.zoneSeconds = zoneSeconds
            }
        }
        record.splits = splits
        return record
    }
}
