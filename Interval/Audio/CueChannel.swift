import Foundation

/// A single output modality for workout cues — audio, haptics,
/// accessibility, etc. Channels are registered with `CueOrchestrator`
/// and fan out semantic `WorkoutCue` events independently.
///
/// Channels must be **cheap and non-blocking** in `emit(_:)` —
/// resources are pre-loaded in `prepareForWorkout()` so the hot path
/// is just "schedule a buffer / fire a pattern".
@MainActor
protocol CueChannel: AnyObject {
    /// Returns `false` when the user has disabled this modality
    /// (e.g. signal tones off) or when the platform doesn't
    /// support it (e.g. no haptics on the device). The orchestrator
    /// checks this before calling `emit(_:)` — channels do **not**
    /// need to guard internally.
    var isEnabled: Bool { get }

    /// Pre-load resources (PCM buffers, haptic patterns) and bring
    /// hardware engines online. Called once when a workout starts.
    /// Must be idempotent so re-running it is safe after a pause.
    func prepareForWorkout()

    /// Render the cue. Called from the main actor at second-boundary
    /// crossings — keep the implementation allocation-free where
    /// possible to avoid latency under tight cue spacing (e.g. the
    /// "three, two, one, GO" sequence).
    func emit(_ cue: WorkoutCue)

    /// Release resources and stop engines. Called when the workout
    /// ends or the active view is dismissed.
    func workoutDidEnd()

    /// Bring the channel's hardware engine back online after the
    /// system ended an audio-session interruption (phone call, Siri,
    /// alarm). Resources stay loaded across the interruption, so this
    /// only needs to restart the engine — not reload buffers/patterns.
    /// Default is a no-op for channels with nothing to restart.
    func resumeAfterInterruption()
}

extension CueChannel {
    func resumeAfterInterruption() {}
}
