import Foundation
import HealthKit
import Observation

@Observable
final class HealthKitManager: NSObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private(set) var isAuthorized = false
    private(set) var currentHeartRate: Int = 0
    private(set) var activeEnergyBurned: Double = 0
    private(set) var distanceWalkingRunning: Double = 0  // in meters
    private(set) var maxHeartRate: Int = 0  // 220 - age, or 0 if unavailable

    // Request authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        isAuthorized = true
        loadMaxHeartRate()
    }

    /// Calculates max heart rate from user's date of birth using the formula: 220 - age
    private func loadMaxHeartRate() {
        guard let dateOfBirth = try? healthStore.dateOfBirthComponents(),
              let birthDate = Calendar.current.date(from: dateOfBirth) else {
            return
        }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        if age > 0 {
            maxHeartRate = 220 - age
        }
    }

    /// Returns the current heart rate zone (1-5) based on percentage of max heart rate.
    /// Returns nil if max heart rate is unavailable or heart rate is 0.
    var currentHeartRateZone: HeartRateZone? {
        guard maxHeartRate > 0, currentHeartRate > 0 else { return nil }
        let percentage = Double(currentHeartRate) / Double(maxHeartRate) * 100
        return HeartRateZone.from(percentage: percentage)
    }

    // Start workout session
    func startWorkout(activityType: HKWorkoutActivityType = .running) throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        session.delegate = self
        builder.delegate = self

        self.workoutSession = session
        self.workoutBuilder = builder

        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { success, error in
            if let error = error {
                print("Failed to begin collection: \(error.localizedDescription)")
            }
        }
    }

    func pauseWorkout() {
        workoutSession?.pause()
    }

    func resumeWorkout() {
        workoutSession?.resume()
    }

    func endWorkout() async throws {
        guard let session = workoutSession, let builder = workoutBuilder else {
            return
        }

        session.end()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: Date()) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishWorkout { workout, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        workoutSession = nil
        workoutBuilder = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState,
                       date: Date) {
        // Handle state changes if needed
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let mostRecentQuantity = statistics.mostRecentQuantity() {
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    let value = mostRecentQuantity.doubleValue(for: heartRateUnit)
                    currentHeartRate = Int(value)
                }
            }

            if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let sumQuantity = statistics.sumQuantity() {
                    activeEnergyBurned = sumQuantity.doubleValue(for: .kilocalorie())
                }
            }

            if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let sumQuantity = statistics.sumQuantity() {
                    distanceWalkingRunning = sumQuantity.doubleValue(for: .meter())
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - Heart Rate Zone

/// Apple-standard heart rate zones based on percentage of max heart rate (220 - age)
enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1  // 50-60% — Zone 1
    case zone2 = 2  // 60-70% — Zone 2
    case zone3 = 3  // 70-80% — Zone 3
    case zone4 = 4  // 80-90% — Zone 4
    case zone5 = 5  // 90-100% — Zone 5

    var name: String {
        "Zone \(rawValue)"
    }

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .zone1: return (0.53, 0.73, 0.87)  // Light blue
        case .zone2: return (0.33, 0.78, 0.47)  // Green
        case .zone3: return (0.95, 0.85, 0.15)  // Yellow
        case .zone4: return (0.95, 0.55, 0.15)  // Orange
        case .zone5: return (0.92, 0.25, 0.20)  // Red
        }
    }

    static func from(percentage: Double) -> HeartRateZone {
        switch percentage {
        case ..<60: return .zone1
        case 60..<70: return .zone2
        case 70..<80: return .zone3
        case 80..<90: return .zone4
        default: return .zone5
        }
    }
}

// MARK: - Error

enum HealthKitError: Error {
    case notAvailable
}
