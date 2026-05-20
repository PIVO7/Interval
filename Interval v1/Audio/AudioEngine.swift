import AVFoundation
import AudioToolbox
import UIKit
import os

/// Manages ambient audio + synthesised signal tones + haptics.
///
/// Signal tone design: "boxing ring" — brassy bell tones with longer ring
/// decay for round-start moments (work / rest / finish), and a short
/// percussive wood tock for the 3-2-1 countdown. All synthesised on the fly
/// — no bundled audio files needed for these effects.
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

    // MARK: - Signal tones — Apple Watch / marimba aesthetic

    /// Start Work: two ascending notes — E5 then G5 (659 → 784 Hz),
    /// Apple-Watch-style transition chime. Soft mallet character, longer
    /// ring so each note has presence.
    func playWorkStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(659, 0.45), (784, 0.70)],
            gap: 0.10,
            style: .marimba
        )
        if settings.hapticsEnabled { haptic(.medium) }
    }

    /// Start Rest: three short taps at E4 (330 Hz) — lower pitch and
    /// triple rhythm.
    func playRestStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(330, 0.30), (330, 0.30), (330, 0.45)],
            gap: 0.07,
            style: .marimba
        )
        if settings.hapticsEnabled { haptic(.soft) }
    }

    /// Last-3-seconds tick: single tap at A5 (880 Hz) — warmer than a
    /// pure beep, longer-ringing so the user feels each tick land before
    /// the next one fires.
    func playCountdownTick(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(880, 0.40)],
            gap: 0,
            style: .marimba
        )
        if settings.hapticsEnabled { haptic(.light) }
    }

    /// Finished: ascending C major arpeggio (C5, E5, G5) with the final
    /// note held longer. Apple-Watch "you closed your rings" character.
    func playFinished(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(523, 0.35), (659, 0.35), (784, 1.0)],
            gap: 0.10,
            style: .marimba
        )
        if settings.hapticsEnabled { haptic(.success) }
    }

    // MARK: - Synth engine

    private var tonePlayer: AVAudioPlayer?

    /// Envelope shape for a tone segment. Drives both the amplitude envelope
    /// and the harmonic recipe (`harmonicRecipe(for:)`).
    private enum SynthStyle {
        /// Marimba/struck-bar — fundamental + strong 4× partial gives the
        /// iconic wooden-bar resonance, with a brief high inharmonic at
        /// attack for the "knock" click. Fast 2ms attack, moderate
        /// exponential decay. Apple Watch aesthetic. Used by all current
        /// signal tones.
        case marimba
        /// Brassy bell with slightly inharmonic partials and long exponential
        /// decay. (Currently unused — kept as an alternative palette.)
        case boxingBell
        /// Wood-block tock — low fundamental, multi-resonance harmonics,
        /// noise transient at attack, very fast decay. (Currently unused.)
        case percussive
        /// Sine pulse with a clean trapezoidal envelope. Digital UI feel.
        /// (Currently unused — kept as an alternative palette.)
        case purePulse
    }

    /// Render and play a sequence of musical segments. Each segment is rendered
    /// with additive harmonics based on its style.
    private func playSynth(
        segments: [(frequency: Double, duration: Double)],
        gap: Double,
        style: SynthStyle
    ) {
        let sampleRate: Double = 44100
        let totalDuration = segments.map(\.duration).reduce(0, +) + gap * Double(segments.count)
        let totalSamples = Int(sampleRate * totalDuration)
        var buffer = [Int16](repeating: 0, count: totalSamples)

        let harmonics = harmonicRecipe(for: style)
        let normalisation = 1.0 / harmonics.map(\.weight).reduce(0, +)

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
                sample *= normalisation * env

                // Wood-block character: add a broadband noise burst at the
                // attack so the tock reads as "heavy mallet striking wood"
                // rather than a pure tone. Stronger + slightly longer than
                // v1 — gives the hit visible bass+grit content.
                if style == .percussive, t < 0.012 {
                    let noiseFade = 1.0 - (t / 0.012)
                    sample += Double.random(in: -1...1) * 0.7 * noiseFade
                }

                // Scale to ~85% peak amplitude — leaves headroom and prevents
                // clipping when harmonics align at the start of decay.
                let scaled = sample * 0.85

                let idx = offset + j
                if idx < buffer.count {
                    buffer[idx] = Int16(clamping: Int(scaled * 32767))
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

    /// Harmonic spectrum. Brassy bells include a 0.5× sub-octave for body
    /// and a slightly-inharmonic 2.76× partial for the "bronze shimmer".
    /// Wood blocks get heavier low content (more weight on fundamental,
    /// preserved upper resonances for the "click") plus the noise transient
    /// added at synthesis time.
    private func harmonicRecipe(for style: SynthStyle) -> [(multiplier: Double, weight: Double)] {
        switch style {
        case .marimba:
            // Toned down from a classic marimba toward a softer "hang
            // drum / kalimba" character: less wood-bar resonance, more
            // body, almost no high-frequency click. Reads as warm and
            // mellow rather than struck-wood.
            return [
                (1.0,  1.00),
                (2.0,  0.28),    // warmth (was 0.18)
                (4.0,  0.28),    // bar partial (was 0.55 — half the marimba flavour)
                (9.7,  0.03),    // very faint attack click (was 0.10)
            ]
        case .boxingBell:
            return [
                (0.5,  0.55),   // sub-octave — adds bass body
                (1.0,  1.00),
                (2.0,  0.45),
                (2.76, 0.30),   // slightly inharmonic — gives bell character
                (4.2,  0.15),
                (5.4,  0.06),
            ]
        case .percussive:
            return [
                (1.0,  1.00),
                (2.8,  0.55),   // first resonant overtone of a struck wood block
                (4.3,  0.30),   // second — adds the high "click"
            ]
        case .purePulse:
            return [
                (1.0, 1.00),    // fundamental
                (2.0, 0.15),    // touch of 2nd harmonic — warmer, less clinical
            ]
        }
    }

    /// Envelope. Boxing bell: 1ms attack + two-stage decay (fast transient
    /// blended with long ring) for that "punchy strike, lingering body" feel.
    /// A 20ms quarter-sine release at the end of each segment prevents the
    /// hard cut-off click when short segments are chained (work/rest/tick).
    /// Percussive: instant attack, fast decay.
    private func envelope(t: Double, duration: Double, style: SynthStyle) -> Double {
        switch style {
        case .marimba:
            // 2ms attack (a struck bar) + slower exponential decay at
            // constant 4.0 (about half the speed of the previous version
            // — ~30% amplitude at 300ms, ~18% at 500ms, ~7% at 800ms),
            // so each note rings noticeably longer. 25ms release tail
            // smooths out the cut at segment end.
            let attack = 0.002
            let release = 0.025
            var env: Double
            if t < attack {
                env = t / attack
            } else {
                env = exp(-(t - attack) * 4.0)
            }
            let timeRemaining = duration - t
            if timeRemaining < release {
                env *= sin(.pi * 0.5 * max(0, timeRemaining) / release)
            }
            return env
        case .boxingBell:
            let attack = 0.001
            let release = 0.02
            var env: Double
            if t < attack {
                env = t / attack
            } else {
                let tAfter = t - attack
                // 40% fast transient (initial impact) + 60% slow body (ring).
                let transient = exp(-tAfter * 18.0)
                let body      = exp(-tAfter * 1.8)
                env = 0.4 * transient + 0.6 * body
            }
            // Smoothly fade to zero across the last `release` seconds of the
            // segment — avoids the click when a 0.3s segment is cut mid-ring.
            let timeRemaining = duration - t
            if timeRemaining < release {
                env *= sin(.pi * 0.5 * max(0, timeRemaining) / release)
            }
            return env
        case .percussive:
            let attack = 0.001
            if t < attack {
                return t / attack
            } else {
                return exp(-(t - attack) * 22.0)
            }
        case .purePulse:
            // Trapezoidal: short linear attack, flat sustain at full
            // amplitude, short linear release. No decay during sustain —
            // gives the clean "digital UI" sound.
            let attack = 0.003
            let release = 0.005
            let timeRemaining = duration - t
            if t < attack {
                return t / attack
            } else if timeRemaining < release {
                return max(0, timeRemaining / release)
            } else {
                return 1.0
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
