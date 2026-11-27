import Foundation
import AVFoundation
#if os(iOS)
import UIKit
import AudioToolbox
#endif

/// Sound + vibration signals for workout playback on iPhone (sound only on Mac).
///
/// Beeps are generated as short sine tones through `AVAudioEngine`, using the
/// `.playback` audio category mixed with other audio, so they play alongside
/// music and aren't muted by the Ring/Silent switch.
final class WorkoutFeedback {
    private let engine = AVAudioEngine()
    private let tonePlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat

    #if os(iOS)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    #endif

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(tonePlayer)
        engine.connect(tonePlayer, to: engine.mainMixerNode, format: format)
    }

    /// Activate audio before the workout starts
    func prepare() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        lightImpact.prepare()
        #endif
        try? engine.start()
    }

    /// Release audio once the workout is over. Delayed so the
    /// workout-complete signal can finish playing.
    func finish() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            tonePlayer.stop()
            engine.stop()
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    // MARK: - Signals

    /// Small tap + soft short beep for 3-2-1 warnings and the lead-in countdown
    func countdownTick() {
        playTone(frequency: 880, duration: 0.08, volume: 0.3)
        #if os(iOS)
        lightImpact.impactOccurred()
        lightImpact.prepare()
        #endif
    }

    /// "Go" at the end of the lead-in countdown
    func go() {
        intervalEnd()
    }

    /// Loud beep + full vibration when a timed interval runs out
    func intervalEnd() {
        playTone(frequency: 1320, duration: 0.4, volume: 0.9)
        vibrate()
    }

    /// Three beeps + vibrations when the whole routine is finished
    func workoutComplete() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) { [self] in
                playTone(frequency: 1320, duration: 0.3, volume: 0.9)
                vibrate()
            }
        }
    }

    /// Route player events to the matching signal
    func handle(_ event: WorkoutPlayer.Event) {
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

    // MARK: - Helpers

    private func vibrate() {
        #if os(iOS)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
    }

    private func playTone(frequency: Double, duration: TimeInterval, volume: Float) {
        // The engine stops after interruptions (e.g. a phone call); restart it
        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning, let buffer = makeTone(frequency: frequency, duration: duration, volume: volume) else { return }
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !tonePlayer.isPlaying {
            tonePlayer.play()
        }
    }

    /// Sine wave with a short fade in/out so it doesn't click
    private func makeTone(frequency: Double, duration: TimeInterval, volume: Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let fadeFrames = Int(0.01 * sampleRate)
        let total = Int(frameCount)
        for frame in 0..<total {
            let envelope = Float(min(1, Double(min(frame, total - frame)) / Double(fadeFrames)))
            samples[frame] = volume * envelope * Float(sin(2 * .pi * frequency * Double(frame) / sampleRate))
        }
        return buffer
    }
}
