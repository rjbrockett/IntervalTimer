import Foundation
import WatchKit

/// Haptic (and system chime) signals for workout playback.
/// watchOS pairs each haptic type with its own sound, which plays
/// unless the watch is silenced.
enum WorkoutFeedback {
    private static var device: WKInterfaceDevice { WKInterfaceDevice.current() }

    /// Small tap for the 3-2-1 warning before an interval ends,
    /// and for each number of the lead-in countdown
    static func countdownTick() {
        device.play(.click)
    }

    /// "Go" at the end of the lead-in countdown
    static func go() {
        device.play(.start)
    }

    /// Strong tap when a timed interval runs out
    static func intervalEnd() {
        device.play(.notification)
    }

    /// Three strong taps when the whole routine is finished
    static func workoutComplete() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                device.play(.notification)
            }
        }
    }

    /// Route player events to the matching signal
    static func handle(_ event: WorkoutPlayer.Event) {
        switch event {
        case .countdownTick:
            countdownTick()
        case .intervalCompleted:
            intervalEnd()
        case .workoutCompleted:
            workoutComplete()
        case .stepEnded:
            break
        }
    }
}
