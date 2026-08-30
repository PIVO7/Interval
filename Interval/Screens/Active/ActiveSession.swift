import Foundation
import Observation

/// App-scoped owner of the running training. Lifting the `TimerEngine` out of
/// `ActiveTrainingView` keeps it alive across the fullscreen cover's dismiss
/// animation and lets `RootTabView` fast-forward it from the wall clock when
/// the app returns to the foreground.
@MainActor
@Observable
final class ActiveSession {
    private(set) var engine: TimerEngine?
    /// Drives the fullScreenCover in `RootTabView`.
    var isPresentingFullScreen = false
    /// Set while the cover's dismiss animation runs after `end()`, so the
    /// engine stays alive for the transition to render against. Cleared in
    /// the cover's `onDismiss`.
    private(set) var isEnding = false

    func start(_ workout: Workout, cues: CueOrchestrating) {
        engine?.stop()
        engine = TimerEngine(workout: workout, cues: cues)
        isEnding = false
        isPresentingFullScreen = true
    }

    /// Stop the training for good. When the cover is up, the engine is
    /// released in `finalizeEnd()` (the cover's `onDismiss`) so the dismiss
    /// animation still has content to render.
    func end() {
        engine?.stop()
        if isPresentingFullScreen {
            isEnding = true
            isPresentingFullScreen = false
        } else {
            engine = nil
        }
    }

    func finalizeEnd() {
        guard isEnding else { return }
        engine = nil
        isEnding = false
    }
}
