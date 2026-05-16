import Foundation
import Combine

enum TrainingPhase {
    case countdown(Int)
    case work
    case rest
    case finished
}

@MainActor
final class TimerEngine: ObservableObject {
    // MARK: - Published state
    @Published var phase: TrainingPhase = .countdown(3)
    @Published var secondsLeft: Int = 0
    @Published var currentRound: Int = 1
    @Published var isPaused: Bool = false
    @Published var progress: Double = 1.0

    // MARK: - Config
    let workout: Workout
    private let audioSettings: AudioSettings
    private let audio = AudioEngine.shared

    // MARK: - Private
    private var timer: AnyCancellable?
    private var phaseTotal: Int = 3

    init(workout: Workout, audioSettings: AudioSettings) {
        self.workout = workout
        self.audioSettings = audioSettings
        startCountdown()
        audio.playAmbient(audioSettings.ambientSound, volume: audioSettings.ambientVolume)
    }

    // MARK: - Public controls
    func togglePause() {
        isPaused.toggle()
        if !isPaused { tick() }
    }

    func skip() {
        advancePhase()
    }

    func stop() {
        timer?.cancel()
        audio.stopAmbient()
    }

    func updateVolume(_ volume: Float) {
        audio.setAmbientVolume(volume)
    }

    // MARK: - Private
    private func startCountdown() {
        phase = .countdown(3)
        secondsLeft = 3
        phaseTotal = 3
        progress = 1.0
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.isPaused else { return }
                self.tick()
            }
    }

    private func tick() {
        // Last-3-seconds countdown ticks
        if secondsLeft <= 3 && secondsLeft > 1 {
            if case .work = phase { audio.playCountdownTick(settings: audioSettings) }
            else if case .rest = phase { audio.playCountdownTick(settings: audioSettings) }
        }

        if secondsLeft > 1 {
            secondsLeft -= 1
            updateProgress()
            if case .countdown(let n) = phase {
                phase = .countdown(n - 1)
            }
        } else if secondsLeft == 1 {
            if case .countdown = phase {
                secondsLeft = 0
                phase = .countdown(0)
                updateProgress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                    self?.advancePhase()
                }
            } else {
                advancePhase()
            }
        }
    }

    private func updateProgress() {
        progress = phaseTotal > 0 ? Double(secondsLeft) / Double(phaseTotal) : 0
    }

    private func advancePhase() {
        switch phase {
        case .countdown:
            beginWork()
        case .work:
            if workout.restSeconds > 0 { beginRest() } else { endRound() }
        case .rest:
            endRound()
        case .finished:
            break
        }
    }

    private func beginWork() {
        phase = .work
        secondsLeft = workout.workSeconds
        phaseTotal = workout.workSeconds
        progress = 1.0
        scheduleTimer()
        audio.playWorkStart(settings: audioSettings)
    }

    private func beginRest() {
        phase = .rest
        secondsLeft = workout.restSeconds
        phaseTotal = workout.restSeconds
        progress = 1.0
        scheduleTimer()
        audio.playRestStart(settings: audioSettings)
    }

    private func endRound() {
        if currentRound < workout.rounds {
            currentRound += 1
            beginWork()
        } else {
            phase = .finished
            timer?.cancel()
            progress = 0
            audio.stopAmbient()
            audio.playFinished(settings: audioSettings)
        }
    }
}
