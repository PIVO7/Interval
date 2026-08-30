import Foundation
import Observation

/// App-scoped owner of the running training. Lifting the `TimerEngine` out of
/// `ActiveTrainingView` lets a session keep ticking (and cueing) while the
/// fullscreen UI is minimized behind the tab bar accessory on iOS 26+ —
/// the user can browse Favorieten/Account while the workout runs on.
@MainActor
@Observable
final class ActiveSession {
    private(set) var engine: TimerEngine?
    /// Drives the fullScreenCover in `RootTabView`.
    var isPresentingFullScreen = false
    /// Set while the cover's dismiss animation runs after `end()`, so the
    /// engine stays alive for the transition to render against but the
    /// accessory never flashes into view. Cleared in the cover's `onDismiss`.
    private(set) var isEnding = false

    /// True when the session should surface in the tab bar accessory.
    var isMinimized: Bool { engine != nil && !isPresentingFullScreen && !isEnding }

    func start(_ workout: Workout, cues: CueOrchestrating) {
        engine?.stop()
        engine = TimerEngine(workout: workout, cues: cues)
        isEnding = false
        isPresentingFullScreen = true
    }

    /// Hide the fullscreen UI but keep the training running (iOS 26+ only —
    /// earlier systems have no accessory to get back in through).
    func minimize() { isPresentingFullScreen = false }

    func reopen() {
        guard engine != nil else { return }
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
