import AVFoundation
import os

/// `CueChannel` that plays bundled voice clips via `AVAudioEngine` +
/// pre-loaded `AVAudioPCMBuffer`s.
///
/// Clips live in `Interval v1/Resources/Audio/` and are bundled by
/// XcodeGen's source glob. Each cue maps to one .m4a file via
/// `clipName(for:)`. Buffers are decompressed into memory in
/// `prepareForWorkout()` and reused for every emit during the workout.
///
/// Latency: ~5 ms host time on `playerNode.scheduleBuffer(_:options:)`
/// — vs. ~20-50 ms for the previous per-cue `AVAudioPlayer`
/// instantiation, because the AAC decode happens once at load time
/// rather than on every cue.
///
/// Audio spec: clips are expected at 44.1 kHz stereo AAC m4a, which
/// matches `AVAudioFormat(standardFormatWithSampleRate: 44100,
/// channels: 2)`. If a clip is missing or has a mismatched format,
/// the load logs a warning and the cue silently no-ops — degraded
/// behaviour rather than a crash.
@MainActor
final class VoicePlayer: CueChannel {
    private let settings: AudioSettings
    private let log = Logger(subsystem: "com.superapp.intervalv1",
                             category: "VoicePlayer")

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var buffers: [BufferKey: AVAudioPCMBuffer] = [:]

    /// `BufferKey` includes the countdown second so 3/2/1 each get
    /// their own pre-loaded buffer (different voice clips per digit).
    private enum BufferKey: Hashable {
        case countdownTick(secondsLeft: Int)
        case workStart
        case halfway
        case lastRound
        case restStart
        case finished
    }

    /// Standard Float32 stereo @ 44.1 kHz — matches the bundled AAC
    /// clips' processing format so `mainMixerNode` doesn't need to
    /// resample or rechannel anything on the hot path.
    private static let voiceFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    }()

    var isEnabled: Bool { settings.signalTonesEnabled }

    init(settings: AudioSettings) {
        self.settings = settings
        engine.attach(playerNode)
        engine.connect(playerNode,
                       to: engine.mainMixerNode,
                       format: Self.voiceFormat)
    }

    func prepareForWorkout() {
        // Idempotent after a pause: buffers are decoded once and reused
        // for the whole workout, so skip the (expensive) AAC re-decode
        // when they're already loaded.
        if buffers.isEmpty { loadBuffers() }
        startEngine()
    }

    /// Restart the engine after the system ended an interruption. The
    /// `AVAudioEngine` is stopped by the OS during a call/Siri/alarm and
    /// does not resume on its own; without this, voice cues would go
    /// silently dead for the rest of the workout.
    func resumeAfterInterruption() {
        guard isEnabled else { return }
        startEngine()
    }

    private func startEngine() {
        guard !engine.isRunning else {
            playerNode.play()
            return
        }
        do {
            try engine.start()
            playerNode.play()
        } catch {
            log.error("Engine start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func emit(_ cue: WorkoutCue) {
        guard let buffer = buffers[bufferKey(for: cue)] else { return }
        // Self-heal: the engine can be stopped by interruption paths that
        // never deliver a recoverable `.ended` (hard session takeover, media
        // services reset). Restarting here means the worst case is one
        // missed cue, never a silently dead rest-of-workout.
        if !engine.isRunning { startEngine() }
        // `.interrupts` makes back-to-back cues (e.g. 3→2→1→GO)
        // replace the previous playback instead of queueing — the
        // older one would otherwise tail into the new cue.
        playerNode.scheduleBuffer(buffer,
                                  at: nil,
                                  options: [.interrupts],
                                  completionHandler: nil)
    }

    func workoutDidEnd() {
        playerNode.stop()
        engine.stop()
        buffers.removeAll()
    }

    // MARK: - Buffer loading

    private func bufferKey(for cue: WorkoutCue) -> BufferKey {
        switch cue {
        case .countdownTick(let n): return .countdownTick(secondsLeft: n)
        case .workStart:            return .workStart
        case .halfway:              return .halfway
        case .lastRound:            return .lastRound
        case .restStart:            return .restStart
        case .finished:             return .finished
        }
    }

    /// Maps a buffer key to the bundled m4a resource name (without
    /// extension). Future cues (`halfway`, `lastRound`) are loaded
    /// here when their `WorkoutCue` cases land.
    private func clipName(for key: BufferKey) -> String {
        switch key {
        case .countdownTick(let n) where n == 3: return "cue_three"
        case .countdownTick(let n) where n == 2: return "cue_two"
        case .countdownTick(let n) where n == 1: return "cue_one"
        case .countdownTick:                     return "cue_one"  // safety net
        case .workStart:                         return "cue_work_start"
        case .halfway:                           return "cue_halfway"
        case .lastRound:                         return "cue_last_round"
        case .restStart:                         return "cue_rest_start"
        case .finished:                          return "cue_finished"
        }
    }

    private func loadBuffers() {
        let keys: [BufferKey] = [
            .countdownTick(secondsLeft: 3),
            .countdownTick(secondsLeft: 2),
            .countdownTick(secondsLeft: 1),
            .workStart,
            .halfway,
            .lastRound,
            .restStart,
            .finished,
        ]
        for key in keys {
            if let buffer = loadBundledBuffer(named: clipName(for: key)) {
                buffers[key] = buffer
            } else {
                log.warning("Voice clip not bundled: \(self.clipName(for: key), privacy: .public)")
            }
        }
    }

    private func loadBundledBuffer(named name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            // Enforce the documented degrade-gracefully contract: a clip
            // whose format doesn't match the node's fixed connection format
            // would raise an NSException (hard crash) at scheduleBuffer.
            // Reject it at load time instead — the cue then no-ops.
            guard file.processingFormat.sampleRate == Self.voiceFormat.sampleRate,
                  file.processingFormat.channelCount == Self.voiceFormat.channelCount else {
                log.error("Rejected \(name, privacy: .public): format \(file.processingFormat, privacy: .public) ≠ 44.1 kHz stereo")
                return nil
            }
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            log.error("Failed to load \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
