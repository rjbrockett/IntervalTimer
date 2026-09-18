import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    
    /// Total distance traveled in meters
    private(set) var totalDistance: Double = 0.0
    
    /// Total distance in miles
    var totalDistanceMiles: Double {
        totalDistance / 1609.34
    }
    
    /// Whether location services are authorized
    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // Update every 5 meters to reduce noise
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = false
    }
    
    /// Request location authorization and start tracking
    func startTracking() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    /// Stop tracking and reset distance
    func stopTracking() {
        manager.stopUpdatingLocation()
        lastLocation = nil
    }
    
    /// Reset distance counter to zero
    func resetDistance() {
        totalDistance = 0.0
        lastLocation = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            // Filter out inaccurate readings
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 20 else {
                continue
            }
            
            if let last = lastLocation {
                let delta = location.distance(from: last)
                // Ignore unrealistically large jumps (GPS drift)
                if delta < 100 {
                    totalDistance += delta
                }
            }
            
            lastLocation = location
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }
}
