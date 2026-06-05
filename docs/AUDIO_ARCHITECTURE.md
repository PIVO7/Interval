# Audio architectuur — ontwerp (review vóór implementatie)

**Status**: papieren ontwerp, niet geïmplementeerd. Bedoeld om de
interfaces te reviewen voor we de huidige `AudioEngine` herschrijven.

---

## Doel

Vervang de huidige monolithische `AudioEngine` (voice + synth + haptic +
audio session) door een gelaagde architectuur die:

- semantische cues uit `TimerEngine` ontkoppelt van hoe ze afgespeeld worden
- per-channel uitbreidbaar is (audio / haptic / now-playing / accessibility)
- testbaar is zonder echte audio hardware nodig
- ruimte heeft voor toekomstige uitbreidingen (Spatial audio, Watch sync,
  background notifications, gelokaliseerde voice clips) zonder herarchitectuur

---

## Begrippen-laag

### `WorkoutCue` — semantisch event

```swift
enum WorkoutCue: Sendable, Hashable {
    case countdownTick(secondsLeft: Int)   // 3, 2, 1
    case workStart
    case restStart
    case halfway                            // toekomst
    case lastRound                          // toekomst
    case finished
    case paused                             // toekomst (AirPods squeeze)
    case resumed                            // toekomst
}
```

`WorkoutCue` is geen audio-event — het is een **gebeurtenis in de
workout** waar verschillende channels op kunnen reageren. De voice
zegt "three", de haptic geeft een tap, de now-playing-laag werkt de
Lock Screen bij. Eén semantisch event, vier output-modaliteiten.

**Spoken description** (voor accessibility & TTS-fallback):

```swift
extension WorkoutCue {
    var spokenDescription: String {
        switch self {
        case .countdownTick(let n): return "\(n)"
        case .workStart:            return "Werk"
        case .restStart:            return "Rust"
        case .halfway:              return "Halverwege"
        case .lastRound:            return "Laatste ronde"
        case .finished:             return "Workout voltooid"
        case .paused:               return "Gepauzeerd"
        case .resumed:              return "Hervat"
        }
    }
}
```

---

## Architectuur

```
┌─────────────────┐
│   TimerEngine   │
└────────┬────────┘
         │ emit(.workStart)
         ▼
┌──────────────────────┐       ┌──────────────────────┐
│  CueOrchestrator     │──────▶│ AudioSessionController│
│ (fanout + lifecycle) │       └──────────────────────┘
└────┬─────────────────┘
     │
     ├────▶ VoicePlayer            (AVAudioEngine + PCM buffers)
     ├────▶ HapticPlayer           (CHHapticEngine + AHAP)
     ├────▶ NowPlayingPublisher    (MPNowPlayingInfoCenter)
     └────▶ AccessibilityAnnouncer (UIAccessibility)
```

---

## Interfaces

### `CueChannel` — uniforme channel-contract

```swift
@MainActor
protocol CueChannel: AnyObject {
    /// Returns `false` when the user has disabled this channel in
    /// settings or when the platform doesn't support it. Channels
    /// must be no-ops in that case — gating at this level avoids
    /// per-call guards everywhere.
    var isEnabled: Bool { get }

    /// Called once before the workout starts. Channels load
    /// resources (PCM buffers, AHAP files) and prepare hardware
    /// (start engines, register remote commands).
    func prepareForWorkout()

    /// Render a cue. Must be cheap and non-blocking — preloaded
    /// resources from `prepareForWorkout` are used.
    func emit(_ cue: WorkoutCue)

    /// Called when the workout ends or the view is dismissed.
    /// Release resources, deactivate sessions.
    func workoutDidEnd()
}
```

**Waarom protocol**: tests injecteren een `MockCueChannel` die alleen
emitted cues bijhoudt — geen AVAudioEngine boot, geen CHHapticEngine
permission prompt, geen MPNowPlayingInfoCenter side effects.

### `CueOrchestrator` — fanout-laag

```swift
@MainActor
final class CueOrchestrator {
    private let channels: [CueChannel]
    private let sessionController: AudioSessionController

    init(channels: [CueChannel],
         sessionController: AudioSessionController) {
        self.channels = channels
        self.sessionController = sessionController
    }

    func prepareForWorkout() {
        sessionController.activate()
        channels.forEach { $0.prepareForWorkout() }
    }

    func emit(_ cue: WorkoutCue) {
        for channel in channels where channel.isEnabled {
            channel.emit(cue)
        }
    }

    func workoutDidEnd() {
        channels.forEach { $0.workoutDidEnd() }
        sessionController.deactivate()
    }
}
```

Heel dun met opzet — alle logica zit in de channels en in
`AudioSessionController`. De orchestrator is enkel een fanout +
lifecycle-coördinator.

### `AudioSessionController` — sessie-lifecycle

```swift
@MainActor
final class AudioSessionController {
    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "AudioSession")

    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
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
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
```

Per-workout activatie i.p.v. permanent — Spotify/Music gaat direct
terug naar 100% volume zodra de workout eindigt.

### `VoicePlayer` — bundled voice clips

```swift
@MainActor
final class VoicePlayer: CueChannel {
    private let settings: AudioSettings
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var buffers: [WorkoutCue: AVAudioPCMBuffer] = [:]

    var isEnabled: Bool { settings.signalTonesEnabled }

    init(settings: AudioSettings) {
        self.settings = settings
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode,
                       format: nil)
    }

    func prepareForWorkout() {
        loadBuffers()
        try? engine.start()
        playerNode.play()
    }

    func emit(_ cue: WorkoutCue) {
        guard let buffer = buffers[cue] else { return }
        // `.interrupts` zorgt dat back-to-back "three, two, one"
        // niet opstapelen — elke nieuwe cue cancelt de vorige.
        playerNode.scheduleBuffer(buffer, at: nil,
                                  options: [.interrupts])
    }

    func workoutDidEnd() {
        playerNode.stop()
        engine.stop()
        buffers.removeAll()
    }

    private func loadBuffers() {
        for cue in WorkoutCue.allBundledCases {
            if let buffer = loadBuffer(for: cue) {
                buffers[cue] = buffer
            }
        }
    }

    private func loadBuffer(for cue: WorkoutCue) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(
            forResource: cue.bundleResourceName,
            withExtension: "m4a"
        ),
        let file = try? AVAudioFile(forReading: url),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { return nil }
        try? file.read(into: buffer)
        return buffer
    }
}
```

**Sleutelpunten**:
- PCM buffers blijven in memory voor de hele workout → ~5 ms latency.
- Buffer reload niet nodig: dezelfde `count_three` buffer wordt elke
  ronde hergebruikt.
- `playerNode.scheduleBuffer(at: nil)` speelt direct af. Voor
  precieze wall-clock-timing: `AVAudioTime` met host time conversie
  (later toevoegen als precision een issue blijkt).
- Geen `prepareToPlay`-per-cue overhead.

### `HapticPlayer` — Core Haptics + AHAP

```swift
@MainActor
final class HapticPlayer: CueChannel {
    private let settings: AudioSettings
    private var engine: CHHapticEngine?
    private var patterns: [WorkoutCue: CHHapticPattern] = [:]

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
            engine = try CHHapticEngine()
            try engine?.start()
            loadPatterns()
        } catch {
            // Haptics zijn altijd optioneel — niet escaleren.
        }
    }

    func emit(_ cue: WorkoutCue) {
        guard let engine, let pattern = patterns[cue] else { return }
        let player = try? engine.makePlayer(with: pattern)
        try? player?.start(atTime: CHHapticTimeImmediate)
    }

    func workoutDidEnd() {
        engine?.stop()
        engine = nil
        patterns.removeAll()
    }
}
```

AHAP-files in `Resources/Haptics/`:
- `cue_countdown.ahap`
- `cue_work_start.ahap`
- `cue_rest_start.ahap`
- `cue_finished.ahap`

### `NowPlayingPublisher` — Lock Screen + Remote Commands

```swift
@MainActor
final class NowPlayingPublisher {
    private var commandTargets: [Any] = []

    func setupRemoteCommands(
        onTogglePause: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        let commands = MPRemoteCommandCenter.shared()
        commandTargets.append(
            commands.togglePlayPauseCommand.addTarget { _ in
                onTogglePause()
                return .success
            }
        )
        commandTargets.append(
            commands.nextTrackCommand.addTarget { _ in
                onSkip()
                return .success
            }
        )
    }

    func update(
        workoutName: String,
        phaseLabel: String,
        round: Int,
        totalRounds: Int,
        elapsedInPhase: TimeInterval,
        phaseDuration: TimeInterval,
        isPaused: Bool
    ) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: workoutName,
            MPMediaItemPropertyArtist: "Ronde \(round)/\(totalRounds) · \(phaseLabel)",
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0 : 1,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedInPhase,
            MPMediaItemPropertyPlaybackDuration: phaseDuration
        ]
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let commands = MPRemoteCommandCenter.shared()
        commands.togglePlayPauseCommand.removeTarget(nil)
        commands.nextTrackCommand.removeTarget(nil)
        commandTargets.removeAll()
    }
}
```

**Let op**: `NowPlayingPublisher` is **geen** `CueChannel` —
hij reageert niet op cues maar op een continue state-update vanuit
`TimerEngine`. Wel geregistreerd in `CueOrchestrator` voor
`prepareForWorkout()` / `workoutDidEnd()` lifecycle.

Alternatief: maak het wél een `CueChannel` en push state via een
extra `func updateState(...)` method. Te bespreken in review.

### `AccessibilityAnnouncer` — VoiceOver

```swift
@MainActor
final class AccessibilityAnnouncer: CueChannel {
    var isEnabled: Bool { UIAccessibility.isVoiceOverRunning }

    func prepareForWorkout() {}

    func emit(_ cue: WorkoutCue) {
        UIAccessibility.post(
            notification: .announcement,
            argument: cue.spokenDescription
        )
    }

    func workoutDidEnd() {}
}
```

Triviale channel — maar verplicht voor App Store-kwaliteit.

---

## TimerEngine-integratie

`TimerEngine` praat **alleen** met `CueOrchestrator`. Geen kennis
van AVAudioEngine, CHHapticEngine, MPNowPlayingInfoCenter.

```swift
@MainActor
@Observable
final class TimerEngine {
    let workout: Workout
    private let cues: CueOrchestrator

    init(workout: Workout, cues: CueOrchestrator) {
        self.workout = workout
        self.cues = cues
        self.cues.prepareForWorkout()
        startCountdown()
    }

    deinit {
        cues.workoutDidEnd()
    }

    // ... fasewissels ...
    private func beginWork() {
        cues.emit(.workStart)
        // ...
    }

    private func beginRest() {
        cues.emit(.restStart)
    }

    private func tick() {
        // ... boundary crossing ...
        if (1...3).contains(newSecondsLeft) {
            cues.emit(.countdownTick(secondsLeft: newSecondsLeft))
        }
    }
}
```

**Vergeleken met huidige code**: één parameter (`cues`) i.p.v. twee
(`audioSettings` + impliciete `AudioEngine.shared`). Geen
`isHeadlessForTesting` flag meer nodig — tests injecteren een
`MockCueOrchestrator`.

---

## Test-architectuur

```swift
@MainActor
final class MockCueOrchestrator: CueOrchestrator {
    var emittedCues: [WorkoutCue] = []
    var preparedForWorkout = false
    var workoutDidEndCalled = false

    override func emit(_ cue: WorkoutCue) {
        emittedCues.append(cue)
    }
    override func prepareForWorkout() { preparedForWorkout = true }
    override func workoutDidEnd() { workoutDidEndCalled = true }
}
```

Of nog cleaner: `CueOrchestrator` zelf een protocol maken zodat de mock
niet hoeft te erven.

Bestaande `TimerEngineTests` blijft 1-op-1 werken — `skip()`-driven
state machine, geen verschil voor wat we testen. Nieuwe tests:

```swift
@Test("Skip from countdown emits workStart cue")
func skipEmitsWorkStart() {
    let cues = MockCueOrchestrator(channels: [], sessionController: ...)
    let engine = TimerEngine(workout: ..., cues: cues)
    engine.skip()
    #expect(cues.emittedCues.contains(.workStart))
}
```

---

## Bundle-resources

Voor v1 zijn voice clips **English-only** (universele fitness-taal,
veel grotere voice library bij ElevenLabs). Geen `.lproj/`-structuur
nodig — clips zitten direct in `Resources/Audio/`. Mocht later een
extra taal toegevoegd worden, dan migreren we naar de gelokaliseerde
opzet onderaan.

```
Interval v1/
└── Resources/
    ├── Audio/                          (English voice clips, niet gelokaliseerd)
    │   ├── cue_three.m4a               ("Three")
    │   ├── cue_two.m4a                 ("Two")
    │   ├── cue_one.m4a                 ("One")
    │   ├── cue_work_start.m4a          ("Go!")
    │   ├── cue_rest_start.m4a          ("Rest")
    │   ├── cue_halfway.m4a             ("Halfway")
    │   ├── cue_last_round.m4a          ("Last round!")
    │   └── cue_finished.m4a            ("Great work!")
    └── Haptics/                        (niet gelokaliseerd)
        ├── cue_countdown.ahap
        ├── cue_work_start.ahap
        ├── cue_rest_start.ahap
        └── cue_finished.ahap
```

**Toekomstige multi-language opzet** (alleen wanneer nodig):

```
Audio/
├── en.lproj/  (huidige clips verhuizen hierheen)
│   ├── cue_three.m4a   ("Three")
│   └── ...
└── nl.lproj/  (nieuwe NL-set)
    ├── cue_three.m4a   ("Drie")
    └── ...
```

`Bundle.main.url(forResource:withExtension:)` resolvet automatisch
naar de juiste locale — geen runtime branching.

`Bundle.main.url(forResource:withExtension:)` resolvet automatisch
naar de actieve locale. Geen runtime branching nodig.

---

## Wat verdwijnt uit de huidige code

- `AudioEngine.playSynth(...)` + `marimbaHarmonics` + `pcmToWAV(...)` —
  alle synth-rendering. Geen dual-path meer.
- `AudioEngine.HapticStyle` enum — vervangen door AHAP-patterns.
- `AudioEngine.shared` singleton — vervangen door dependency-injected
  `CueOrchestrator` in `IntervalApp` als `.environment(...)`.
- `TimerEngine.isHeadlessForTesting` flag — niet meer nodig zodra
  cues door een mockable orchestrator gaan.

Te behouden:
- `AudioSettings` (signalTonesEnabled, hapticsEnabled) — properties
  blijven, maar worden door `VoicePlayer`/`HapticPlayer` gelezen i.p.v.
  doorgegeven per cue.

---

## Open vragen voor review

1. **`NowPlayingPublisher` als `CueChannel`?** Nu apart behandeld omdat
   hij state-driven is, niet event-driven. Andere optie: alle channels
   krijgen ook een `updateState(...)`. Voorkeur: aparte type houden,
   eerlijker over de modaliteit.

2. **`AudioSessionController` binnen of buiten `CueOrchestrator`?** Nu
   binnen (orchestrator activeert/deactiveert). Alternative: aparte
   environment-injected service. Voorkeur: binnen orchestrator —
   lifecycle is gekoppeld aan workout-lifecycle.

3. **TTS-fallback voor ontbrekende voice clips?** `VoicePlayer` met
   ontbrekende buffer doet nu niets. Optie: fallback naar
   `AVSpeechSynthesizer` met `cue.spokenDescription`. Voorkeur:
   niet doen — clips bundlen of niet, geen dual-path.

4. **Precision timing**: nu `scheduleBuffer(at: nil)` = direct
   afspelen. Voor exact-op-de-milliseconde timing: `AVAudioTime` met
   host time conversie. Voorkeur: pas later toevoegen als testers
   merken dat cues "te laat" voelen.

5. **Background audio**: dit ontwerp ondersteunt het niet
   automatisch. `UNNotificationRequest`-scheduling moet een aparte
   `BackgroundCueScheduler` worden die parallel aan `CueOrchestrator`
   draait, geen channel binnen de orchestrator. Voorkeur: separate
   feature, niet in v1 van deze refactor.

6. **Watch-app integratie**: out of scope voor deze refactor, maar de
   `CueOrchestrator`-laag is wat je later op de Watch dupliceert.
   Engine zelf raakt niet aan.

---

## Migratie-volgorde (na review)

1. `WorkoutCue` enum + `CueChannel` protocol + `CueOrchestrator` skelet
   toevoegen, **niet wired**.
2. `AudioSessionController` toevoegen, **niet wired**.
3. `VoicePlayer` schrijven met synth-buffers gegenereerd vanuit huidige
   marimba-code → drop-in compatible met huidige cues.
4. `HapticPlayer` met simple impacts (geen AHAP nog, eerst de plumbing).
5. `IntervalApp` injecteert `CueOrchestrator` via `.environment(...)`.
6. `TimerEngine` constructor accepteert `CueOrchestrator` i.p.v.
   `AudioSettings`. Bestaande callsites omschrijven.
7. Tests: `MockCueOrchestrator`, `TimerEngineTests` migreren.
8. `AudioEngine` oude file deleten.
9. AHAP-patronen schrijven, `HapticPlayer` upgraden.
10. `NowPlayingPublisher` toevoegen + remote commands wiren in
    `ActiveTrainingView`.
11. Voice clips bundelen, synth-buffers in `VoicePlayer` verwijderen.
12. (later) `BackgroundCueScheduler` voor locked-screen support.
13. (later) Localized voice clips, Watch companion.

---

## Reviewpunten — geef feedback op:

- [ ] Naamgeving (`WorkoutCue` vs `Cue` vs `Signal`)
- [ ] `CueChannel` protocol oppervlakte — te smal / te breed?
- [ ] `NowPlayingPublisher` apart of als channel?
- [ ] Open vragen 1-6 hierboven
- [ ] Migratie-volgorde — eerst plumbing of eerst clips?
