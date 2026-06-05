import Foundation

/// Semantic event emitted by `TimerEngine` at workout state transitions.
///
/// A cue is not an audio event — it's a description of "what just
/// happened in the workout". Each registered `CueChannel` decides
/// for itself how to react: VoicePlayer plays a clip, HapticPlayer
/// fires a pattern, AccessibilityAnnouncer posts a VoiceOver
/// announcement, etc.
enum WorkoutCue: Sendable, Hashable {
    /// Tick during the last-3-seconds countdown of any phase.
    /// `secondsLeft` is 1, 2, or 3.
    case countdownTick(secondsLeft: Int)

    /// A work block has started (countdown finished or rest ended).
    /// Emitted instead of `.halfway` or `.lastRound` when neither
    /// applies for the round being entered.
    case workStart

    /// Replaces `.workStart` for the round that lands on the workout's
    /// halfway point. Only fires for workouts with at least 4 rounds
    /// (smaller workouts go straight to `.lastRound`).
    case halfway

    /// Replaces `.workStart` for the final round's work block. Only
    /// fires when total rounds ≥ 2 (no point announcing "last round"
    /// when there's only one round).
    case lastRound

    /// A rest block has started (work ended, more rounds remain).
    case restStart

    /// The entire workout is complete.
    case finished
}

extension WorkoutCue {
    /// Plain-language description used by `AccessibilityAnnouncer`
    /// for VoiceOver. Localized via `Localizable.xcstrings` — Dutch
    /// source, so Dutch-locale users (the primary audience) hear
    /// Dutch announcements.
    ///
    /// This is intentionally separate from the bundled voice clips
    /// (which are English regardless of locale). Audio cues are a
    /// "brand voice" channel; VoiceOver is an accessibility channel
    /// that should match the user's chosen system language.
    var spokenDescription: String {
        switch self {
        case .countdownTick(let n):
            return String(localized: "\(n)")
        case .workStart:
            return String(localized: "Werk")
        case .halfway:
            return String(localized: "Halverwege")
        case .lastRound:
            return String(localized: "Laatste ronde")
        case .restStart:
            return String(localized: "Rust")
        case .finished:
            return String(localized: "Workout voltooid")
        }
    }
}
