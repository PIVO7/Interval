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

    // MARK: - Signal tones

    /// Start Work: TWO bells ascending — A4 then C#5 (440 → 550 Hz). The
    /// rising major third reads as "Ready · GO". Each bell is ~0.55s with a
    /// short gap, so the whole signal lands in ~1.25s total.
    func playWorkStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(440, 0.55), (550, 0.55)],
            gap: 0.15,
            style: .boxingBell
        )
        if settings.hapticsEnabled { haptic(.heavy) }
    }

    /// Start Rest: THREE short bells at E4 (330 Hz). Same-pitch triple
    /// pulse — recognisably a different rhythm from work-start, lower in
    /// pitch so it reads "wind down" rather than "go". ~1.2s total.
    func playRestStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(330, 0.30), (330, 0.30), (330, 0.30)],
            gap: 0.10,
            style: .boxingBell
        )
        if settings.hapticsEnabled { haptic(.medium) }
    }

    /// Last-3-seconds tick: clear pitched note at E5 (660 Hz) — high and
    /// bright so each tick reads as a distinct warning beep above the
    /// work-start bell range. ~0.25s duration with the bell-style ring.
    func playCountdownTick(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [(660, 0.25)],
            gap: 0,
            style: .boxingBell
        )
        if settings.hapticsEnabled { haptic(.light) }
    }

    /// Finished: classic three-bell boxing match-end signal. Three rings of
    /// the work-start bell — the last one held longer for resolution.
    func playFinished(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(
            segments: [
                (440, 0.55),
                (440, 0.55),
                (440, 1.5),
            ],
            gap: 0.20,
            style: .boxingBell
        )
        if settings.hapticsEnabled { haptic(.success) }
    }

    // MARK: - Synth engine

    private var tonePlayer: AVAudioPlayer?

    /// Envelope shape for a tone segment. Drives both the amplitude envelope
    /// and the harmonic recipe (`harmonicRecipe(for:)`).
    private enum SynthStyle {
        /// Brassy bell with slightly inharmonic partials and long exponential
        /// decay. Used for round / rest / finish signals.
        case boxingBell
        /// Wood-block tock — low fundamental, multi-resonance harmonics,
        /// noise transient at attack, very fast decay. Used for countdown.
        case percussive
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
        }
    }

    /// Envelope. Boxing bell: 1ms attack + two-stage decay (fast transient
    /// blended with long ring) for that "punchy strike, lingering body" feel.
    /// A 20ms quarter-sine release at the end of each segment prevents the
    /// hard cut-off click when short segments are chained (work/rest/tick).
    /// Percussive: instant attack, fast decay.
    private func envelope(t: Double, duration: Double, style: SynthStyle) -> Double {
        switch style {
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
