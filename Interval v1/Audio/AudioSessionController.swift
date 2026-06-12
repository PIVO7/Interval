import AVFoundation
import os

/// Manages the shared `AVAudioSession` lifecycle for a workout.
///
/// Activated when a workout starts so cues duck any background music
/// during the session, and deactivated when it ends so Music/Spotify
/// return to full volume immediately. Permanent activation (the old
/// `AudioEngine` pattern) would leave music ducked even when the
/// timer isn't running.
@MainActor
final class AudioSessionController {
    private let log = Logger(subsystem: "com.superapp.intervalv1",
                             category: "AudioSession")

    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            // `.duckOthers` lowers background music for as long as this
            // session is ACTIVE — i.e. for the entire workout, not just
            // during cues (per-cue activate/deactivate would add latency
            // and volume flicker). `.interruptSpokenAudioAndMixWithOthers`
            // pauses podcasts/audiobooks for the session (mid-sentence
            // ducking would be worse) and mixes with music. Deliberate
            // trade-off: music plays quieter during training, restored
            // by `deactivate()` the moment the workout ends.
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers,
                          .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            log.error("Activate failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deactivate() {
        do {
            // `.notifyOthersOnDeactivation` tells Spotify/Music that
            // we're done — they pop back to 100 % volume immediately
            // instead of staying ducked until the user touches their
            // playback controls.
            try AVAudioSession.sharedInstance()
                .setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Deactivate failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
