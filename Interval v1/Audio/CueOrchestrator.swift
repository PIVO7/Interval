import AVFoundation
import Foundation

/// Abstraction `TimerEngine` depends on so tests can inject a mock
/// without spinning up audio / haptic hardware.
@MainActor
protocol CueOrchestrating: AnyObject {
    func prepareForWorkout()
    func emit(_ cue: WorkoutCue)
    func workoutDidEnd()
}

/// Fanout layer between `TimerEngine` and the cue channels.
///
/// Holds the registered `CueChannel`s and the `AudioSessionController`,
/// and dispatches lifecycle calls + per-cue emits in lockstep. No
/// per-channel business logic lives here — each channel decides what
/// to do with a cue (or to ignore it).
@MainActor
@Observable
final class CueOrchestrator: CueOrchestrating {
    // `@ObservationIgnored` on the channels/sessionController — the
    // orchestrator has no observable state for SwiftUI views to read,
    // it only conforms to `Observable` so it can ride `.environment(_:)`.
    @ObservationIgnored private let channels: [CueChannel]
    @ObservationIgnored private let sessionController: AudioSessionController

    // Active only between `prepareForWorkout()` and `workoutDidEnd()`,
    // so interruption recovery never reactivates the session when the
    // timer is idle.
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?

    init(channels: [CueChannel],
         sessionController: AudioSessionController) {
        self.channels = channels
        self.sessionController = sessionController
    }

    func prepareForWorkout() {
        isActive = true
        registerInterruptionObserver()
        sessionController.activate()
        for channel in channels {
            channel.prepareForWorkout()
        }
    }

    func emit(_ cue: WorkoutCue) {
        for channel in channels where channel.isEnabled {
            channel.emit(cue)
        }
    }

    func workoutDidEnd() {
        // Idempotent: stop() reaches here via multiple routes (Stop button +
        // onDisappear). The second call would redundantly re-stop channels
        // and deactivate an already-inactive session.
        guard isActive else { return }
        isActive = false
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        for channel in channels {
            channel.workoutDidEnd()
        }
        sessionController.deactivate()
    }

    // MARK: - Interruption recovery

    private func registerInterruptionObserver() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            // `queue: .main` guarantees main-thread delivery, so it's
            // safe to re-enter the main actor synchronously.
            MainActor.assumeIsolated {
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard isActive,
              let info = notification.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            // System has paused our audio; nothing to do until it ends.
            break
        case .ended:
            let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            guard options.contains(.shouldResume) else { return }
            sessionController.activate()
            for channel in channels {
                channel.resumeAfterInterruption()
            }
        @unknown default:
            break
        }
    }
}

extension CueOrchestrator {
    /// Convenience factory wiring the default channel stack (voice +
    /// haptics) against the user's `AudioSettings`. App-level callers
    /// use this; tests build a `MockCueOrchestrator` instead.
    static func makeDefault(settings: AudioSettings) -> CueOrchestrator {
        CueOrchestrator(
            channels: [
                VoicePlayer(settings: settings),
                HapticPlayer(settings: settings),
            ],
            sessionController: AudioSessionController()
        )
    }
}
