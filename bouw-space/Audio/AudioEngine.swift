import AVFoundation
import AudioToolbox
import UIKit

/// Manages ambient audio + synthesised signal tones + haptics.
final class AudioEngine {

    static let shared = AudioEngine()

    private var ambientPlayer: AVAudioPlayer?
    private var session: AVAudioSession { AVAudioSession.sharedInstance() }

    private init() { configureSession() }

    // MARK: - Session
    private func configureSession() {
        do {
            try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            NSLog("[AudioEngine] Session setup failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Ambient
    func playAmbient(_ sound: AmbientSound, volume: Float) {
        stopAmbient()
        guard sound != .none else { return }
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3")
                     ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
            NSLog("[AudioEngine] Ambient file not found: %@", sound.rawValue)
            return
        }
        do {
            ambientPlayer = try AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1
            ambientPlayer?.volume = volume
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
        } catch {
            NSLog("[AudioEngine] Ambient playback error: %@", error.localizedDescription)
        }
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func setAmbientVolume(_ volume: Float) {
        ambientPlayer?.volume = volume
    }

    // MARK: - Signal tones (synthesised via AudioToolbox SystemSoundID)
    // We generate raw PCM buffers and play via AVAudioPlayer for precise control.

    func playWorkStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(frequencies: [660, 880], durations: [0.18, 0.22], gap: 0.04)
        if settings.hapticsEnabled { haptic(.medium) }
    }

    func playRestStart(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(frequencies: [660, 440], durations: [0.18, 0.22], gap: 0.04)
        if settings.hapticsEnabled { haptic(.medium) }
    }

    func playCountdownTick(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(frequencies: [550], durations: [0.08], gap: 0)
        if settings.hapticsEnabled { haptic(.light) }
    }

    func playFinished(settings: AudioSettings) {
        guard settings.signalTonesEnabled else { return }
        playSynth(frequencies: [660, 784, 1046], durations: [0.3, 0.3, 0.6], gap: 0.06)
        if settings.hapticsEnabled { haptic(.success) }
    }

    // MARK: - Synth engine
    private var tonePlayer: AVAudioPlayer?

    private func playSynth(frequencies: [Double], durations: [Double], gap: Double) {
        let sampleRate: Double = 44100
        let totalSamples = Int(sampleRate * (zip(durations, frequencies).map { $0.0 }.reduce(0, +) + gap * Double(frequencies.count)))
        var buffer = [Int16](repeating: 0, count: totalSamples)

        var offset = 0
        for (i, freq) in frequencies.enumerated() {
            let dur = durations[min(i, durations.count - 1)]
            let count = Int(sampleRate * dur)
            for j in 0..<count {
                let t = Double(j) / sampleRate
                // Envelope: quick attack, smooth release
                let env = min(1.0, t / 0.01) * max(0.0, 1.0 - (t - dur * 0.7) / (dur * 0.3))
                let sample = sin(2 * .pi * freq * t) * env * 0.55
                let idx = offset + j
                if idx < buffer.count {
                    buffer[idx] = Int16(clamping: Int(sample * 32767))
                }
            }
            offset += count
            // gap silence
            let gapCount = Int(sampleRate * gap)
            offset = min(offset + gapCount, buffer.count)
        }

        // Write to temp wav and play
        let data = pcmToWAV(buffer: buffer, sampleRate: Int(sampleRate))
        do {
            tonePlayer = try AVAudioPlayer(data: data)
            tonePlayer?.volume = 0.85
            tonePlayer?.play()
        } catch {
            NSLog("[AudioEngine] Tone play error: %@", error.localizedDescription)
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
    enum HapticStyle { case light, medium, success }

    private func haptic(_ style: HapticStyle) {
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
