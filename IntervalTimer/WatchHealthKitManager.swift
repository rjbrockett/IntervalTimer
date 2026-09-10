#if os(watchOS)
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
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        isAuthorized = true
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
        
        try await builder.endCollection(withEnd: Date())
        
        let _ = try await builder.finishWorkout()
        
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
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - Error

enum HealthKitError: Error {
    case notAvailable
}
#endif
