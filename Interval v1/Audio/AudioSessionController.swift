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
            // `.duckOthers` drops background music to ~50 % during
            // each cue and restores it after, the Apple Fitness
            // pattern. `.interruptSpokenAudioAndMixWithOthers`
            // pauses podcasts (where ducking would be confusing
            // mid-sentence) and mixes with music.
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
