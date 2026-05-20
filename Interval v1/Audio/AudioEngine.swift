import AVFoundation
import AudioToolbox
import UIKit
import os

/// Manages ambient audio + synthesised signal tones + haptics.
final class AudioEngine {

    static let shared = AudioEngine()

    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "AudioEngine")
    private var ambientPlayer: AVAudioPlayer?
    private var session: AVAudioSession { AVAudioSession.sharedInstance() }

    private init() { configureSession() }

    // MARK: - Session
    private func configureSession() {
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            log.error("Session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Ambient

    /// True if the bundled audio file for this sound exists. UI can use this
    /// to grey-out unavailable options or omit them from the picker.
    static func isAvailable(_ sound: AmbientSound) -> Bool {
        guard sound != .none else { return true }
        return Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") != nil
            || Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") != nil
    }

    func playAmbient(_ sound: AmbientSound, volume: Float) {
        stopAmbient()
        guard sound != .none else { return }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3")
                     ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
            log.warning("Ambient file not bundled — skipping playback: \(sound.rawValue, privacy: .public)")
            return
        }
        do {
            ambientPlayer = try AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1
            ambientPlayer?.volume = volume
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
        } catch {
            log.error("Ambient playback error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func setAmbientVolume(_ volume: Float) {
        ambientPlayer?.volume = volume
    }

    // MARK: - Signal tones (synthesised — additive synthesis with bell-like
    // harmonics, sine attack, exponential decay. Tuned to musical intervals
    // instead of octaves for a warmer, less clinical character.)

    /// Musical note frequencies (equal-temperament, A4 = 440 Hz). All chimes
    /// sit in the mid range (C4–G4) which is the warm zone for phone speakers
    /// — high enough to be clearly audible, low enough to feel soft.
    private enum Note {
        static let c4: Double = 261.63
        static let e4: Double = 329.63
        static let g4: Double = 392.00
    }

    /// Start Work: C4 → E4 → G4 — rising major triad arpeggio. Longer + more
    /// note movement gives a "ready-set-go" fanfare feel. Heavy haptic to match.
    func playWorkStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(Note.c4, 0.18), (Note.e4, 0.18), (Note.g4, 0.70)],
            gap: 0.02
        )
        if settings.hapticsEnabled { haptic(.heavy) }
    }

    /// Start Rest: G4 → E4 — short descending third. Half the work duration
    /// (~0.5s vs ~1.05s) — feels like a brief breath. Soft haptic to match.
    func playRestStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(segments: [(Note.g4, 0.14), (Note.e4, 0.32)], gap: 0.02)
        if settings.hapticsEnabled { haptic(.soft) }
    }

    /// Last-3-seconds tick: short percussive E4 — soft wood-block "tap".
    func playCountdownTick(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(segments: [(Note.e4, 0.10)], gap: 0, style: .percussive)
        if settings.hapticsEnabled { haptic(.light) }
    }

    /// Finished: C major arpeggio C4–E4–G4 with sustained final note.
    func playFinished(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(Note.c4, 0.24), (Note.e4, 0.24), (Note.g4, 0.95)],
            gap: 0.02
        )
        if settings.hapticsEnabled { haptic(.success) }
    }

    // MARK: - Synth engine

    private var tonePlayer: AVAudioPlayer?

    /// Envelope shape for a tone segment.
    private enum SynthStyle {
        /// Soft sine attack (~40ms), exponential decay. Bell / chime feel.
        case bell
        /// Very fast attack (~5ms), fast decay. Wood-block / click feel.
        case percussive
    }

    /// Render and play a sequence of musical segments. Each segment is rendered
    /// with additive harmonics (fundamental + 2nd + 3rd + 4th) for richness.
    private func playSynth(
        segments: [(frequency: Double, duration: Double)],
        gap: Double,
        style: SynthStyle = .bell
    ) {
        let sampleRate: Double = 44100
        let totalDuration = segments.map(\.duration).reduce(0, +) + gap * Double(segments.count)
        let totalSamples = Int(sampleRate * totalDuration)
        var buffer = [Int16](repeating: 0, count: totalSamples)

        // Harmonic recipe: mostly fundamental + a touch of octave + faint 5th
        // for warmth without brilliance. The 4th harmonic is dropped entirely
        // — at our chime frequencies (C4–G4) it sits in the piercing 1.5kHz
        // range, exactly what we want to avoid.
        let harmonics: [(multiplier: Double, weight: Double)] = [
            (1.0, 1.00),
            (2.0, 0.22),
            (3.0, 0.04),
        ]

        var offset = 0
        for segment in segments {
            let sampleCount = Int(sampleRate * segment.duration)
            for j in 0..<sampleCount {
                let t = Double(j) / sampleRate
                let env = envelope(t: t, duration: segment.duration, style: style)

                var sample = 0.0
                for h in harmonics {
                    sample += sin(2 * .pi * segment.frequency * h.multiplier * t) * h.weight
                }
                // Normalise: sum of weights ≈ 1.52, plus headroom for envelope.
                sample *= env * 0.34

                let idx = offset + j
                if idx < buffer.count {
                    buffer[idx] = Int16(clamping: Int(sample * 32767))
                }
            }
            offset += sampleCount + Int(sampleRate * gap)
            if offset >= buffer.count { break }
        }

        let data = pcmToWAV(buffer: buffer, sampleRate: Int(sampleRate))
        do {
            tonePlayer = try AVAudioPlayer(data: data)
            tonePlayer?.volume = 0.9
            tonePlayer?.play()
        } catch {
            log.error("Tone play error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Envelope function. Bell: smooth sine attack, exponential decay.
    /// Percussive: near-instant attack, fast exponential decay.
    private func envelope(t: Double, duration: Double, style: SynthStyle) -> Double {
        switch style {
        case .bell:
            let attack = 0.04
            if t < attack {
                // Quarter-sine ramp 0 → 1 — gentle onset, no click
                return sin(.pi * 0.5 * (t / attack))
            } else {
                // Exponential decay, scaled so the tone fades out by ~end-of-segment
                let decayTime = t - attack
                return exp(-decayTime * 3.2)
            }
        case .percussive:
            let attack = 0.005
            if t < attack {
                return t / attack
            } else {
                return exp(-(t - attack) * 22.0)
            }
        }
    }

    // MARK: - WAV helper
    private func pcmToWAV(buffer: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign: UInt16 = numChannels * bitsPerSample / 8
        let dataSize = UInt32(buffer.count * 2)
        let chunkSize = 36 + dataSize

        var data = Data()
        func appendUInt32(_ v: UInt32) { var x = v.littleEndian; data.append(contentsOf: withUnsafeBytes(of: &x, Array.init)) }
        func appendUInt16(_ v: UInt16) { var x = v.littleEndian; data.append(contentsOf: withUnsafeBytes(of: &x, Array.init)) }
        func appendASCII(_ s: String)  { data.append(contentsOf: s.utf8) }

        appendASCII("RIFF")
        appendUInt32(chunkSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendUInt32(16)
        appendUInt16(1)                    // PCM
        appendUInt16(numChannels)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(byteRate)
        appendUInt16(blockAlign)
        appendUInt16(bitsPerSample)
        appendASCII("data")
        appendUInt32(dataSize)

        buffer.forEach { sample in
            var s = sample.littleEndian
            data.append(contentsOf: withUnsafeBytes(of: &s, Array.init))
        }
        return data
    }

    // MARK: - Haptic
    enum HapticStyle { case soft, light, medium, heavy, success }

    private func haptic(_ style: HapticStyle) {
        switch style {
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
