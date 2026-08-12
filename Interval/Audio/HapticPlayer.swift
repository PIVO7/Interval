import CoreHaptics
import os

/// `CueChannel` that fires Core Haptics patterns at workout cues.
///
/// **Current state**: patterns are constructed programmatically with
/// `CHHapticEvent`s tuned to roughly match the previous
/// `UIImpactFeedbackGenerator` feel. When a designer takes a pass,
/// these can be replaced with AHAP files from `Resources/Haptics/`
/// without touching `emit(_:)` — the lookup just changes its source.
@MainActor
final class HapticPlayer: CueChannel {
    private let settings: AudioSettings
    private let log = Logger(subsystem: "com.superapp.interval",
                             category: "HapticPlayer")

    private var engine: CHHapticEngine?
    private var patterns: [PatternKey: CHHapticPattern] = [:]

    private enum PatternKey: Hashable {
        case countdownTick
        case workStart
        case restStart
        case finished
    }

    var isEnabled: Bool {
        settings.hapticsEnabled &&
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    init(settings: AudioSettings) {
        self.settings = settings
    }

    func prepareForWorkout() {
        guard isEnabled else { return }
        do {
            let engine = try CHHapticEngine()
            // Recover automatically if the engine is reset by the
            // system (audio session interruption, app backgrounding).
            // CHHapticEngine invokes this on an internal queue, so hop
            // back to the main actor before touching isolated state.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            try engine.start()
            self.engine = engine
            patterns = buildPatterns()
        } catch {
            // Haptics are always optional — log + degrade silently.
            log.error("Engine start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func emit(_ cue: WorkoutCue) {
        guard let engine, let pattern = patterns[patternKey(for: cue)] else { return }
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.error("Pattern playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Restart the haptic engine after an interruption ends. The
    /// `resetHandler` already covers most resets, but a session
    /// interruption can stop the engine without triggering it, so
    /// restart explicitly here too. Patterns survive, so no rebuild.
    func resumeAfterInterruption() {
        guard isEnabled, let engine else { return }
        try? engine.start()
    }

    func workoutDidEnd() {
        engine?.stop()
        engine = nil
        patterns.removeAll()
    }

    // MARK: - Pattern construction

    private func patternKey(for cue: WorkoutCue) -> PatternKey {
        switch cue {
        case .countdownTick:                return .countdownTick
        // halfway / lastRound reuse the workStart pattern — the
        // hardware distinction lives in the voice clip, not the
        // haptic. Adding bespoke AHAP patterns for these is a
        // future refinement once a designer takes a pass.
        case .workStart, .halfway, .lastRound: return .workStart
        case .restStart:                    return .restStart
        case .finished:                     return .finished
        }
    }

    private func buildPatterns() -> [PatternKey: CHHapticPattern] {
        var result: [PatternKey: CHHapticPattern] = [:]
        if let p = transient(intensity: 0.45, sharpness: 0.65) {
            result[.countdownTick] = p
        }
        if let p = transient(intensity: 0.80, sharpness: 0.55) {
            result[.workStart] = p
        }
        if let p = transient(intensity: 0.50, sharpness: 0.30) {
            result[.restStart] = p
        }
        if let p = celebration() {
            result[.finished] = p
        }
        return result
    }

    private func transient(intensity: Float, sharpness: Float) -> CHHapticPattern? {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        return try? CHHapticPattern(events: [event], parameters: [])
    }

    /// Three ascending transients — a "you did it" cascade that
    /// roughly maps to the old `.success` notification feedback but
    /// with more character.
    private func celebration() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0.00
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                ],
                relativeTime: 0.12
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                ],
                relativeTime: 0.28
            ),
        ]
        return try? CHHapticPattern(events: events, parameters: [])
    }
}
