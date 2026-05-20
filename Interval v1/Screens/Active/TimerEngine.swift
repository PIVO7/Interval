import Foundation
import Observation

enum TrainingPhase {
    case countdown(Int)
    case work
    case rest
    case finished
}

@MainActor
@Observable
final class TimerEngine {
    // MARK: - Published state
    var phase: TrainingPhase = .countdown(3)
    var secondsLeft: Int = 0
    var currentRound: Int = 1
    var isPaused: Bool = false
    var progress: Double = 1.0

    // MARK: - Config
    let workout: Workout
    private let audioSettings: AudioSettings
    private let audio = AudioEngine.shared

    // MARK: - Wall-clock state
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var phaseTotal: Int = 3
    @ObservationIgnored private var phaseStartedAt: Date = .now
    @ObservationIgnored private var phaseEndsAt: Date = .now
    @ObservationIgnored private var pausedAt: Date?
    /// Tracks the last whole-second value emitted, so we only play 3-2-1
    /// countdown ticks once per second boundary regardless of tick rate.
    @ObservationIgnored private var lastEmittedSecond: Int = -1
    /// Suppresses per-phase Live Activity pushes while we fast-forward many
    /// phases at once (foreground catch-up). One push at the end keeps us
    /// well under iOS's background update budget.
    @ObservationIgnored private var suppressActivityUpdates = false

    init(workout: Workout, audioSettings: AudioSettings) {
        self.workout = workout
        self.audioSettings = audioSettings
        audio.playAmbient(audioSettings.ambientSound, volume: audioSettings.ambientVolume)
        startCountdown()
        Task {
            await LiveActivityManager.shared.start(
                workoutName: workout.name,
                totalRounds: workout.rounds,
                phase: .countdown,
                round: 1,
                start: phaseStartedAt,
                end: phaseEndsAt
            )
        }
    }

    deinit {
        tickTask?.cancel()
    }

    // MARK: - Public controls
    func togglePause() {
        if isPaused {
            // Resume — shift the schedule forward by the pause duration so
            // secondsLeft doesn't lurch and the Live Activity stays correct.
            if let pausedAt {
                let delta = Date.now.timeIntervalSince(pausedAt)
                phaseStartedAt = phaseStartedAt.addingTimeInterval(delta)
                phaseEndsAt = phaseEndsAt.addingTimeInterval(delta)
            }
            pausedAt = nil
            isPaused = false
            scheduleTimer()
            tick()
        } else {
            pausedAt = .now
            isPaused = true
            tickTask?.cancel()
        }
        pushActivityUpdate()
    }

    func skip() {
        advancePhase()
    }

    func stop() {
        tickTask?.cancel()
        audio.stopAmbient()
        Task { await LiveActivityManager.shared.endImmediately() }
    }

    func updateVolume(_ volume: Float) {
        audio.setAmbientVolume(volume)
    }

    /// Called when the app returns to the foreground — fast-forward through
    /// any phase boundaries that completed while we were suspended, then
    /// push a single Live Activity update with the landing phase.
    func recomputeFromWallClock() {
        guard !isPaused else { return }
        suppressActivityUpdates = true
        defer { suppressActivityUpdates = false }
        var didAdvance = false
        var guardCounter = 0
        let maxIterations = max(8, workout.rounds * 2 + 4)
        while !isFinished, Date.now >= phaseEndsAt, guardCounter < maxIterations {
            advancePhase()
            didAdvance = true
            guardCounter += 1
        }
        if didAdvance {
            // Reset before pushing so the update actually goes out.
            suppressActivityUpdates = false
            pushActivityUpdate()
        }
        tick()
    }

    // MARK: - Private
    private var isFinished: Bool {
        if case .finished = phase { true } else { false }
    }

    private func startCountdown() {
        phase = .countdown(3)
        phaseTotal = 3
        phaseStartedAt = .now
        phaseEndsAt = phaseStartedAt.addingTimeInterval(3)
        secondsLeft = 3
        progress = 1.0
        lastEmittedSecond = 3
        scheduleTimer()
    }

    private func scheduleTimer() {
        tickTask?.cancel()
        // 4 Hz: smooth visual countdown, and because each tick reads the wall
        // clock we never miss a second boundary even if the runloop hiccups.
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { break }
                if !self.isPaused { self.tick() }
            }
        }
    }

    private func tick() {
        let reference = pausedAt ?? .now
        let remaining = max(0, phaseEndsAt.timeIntervalSince(reference))
        let newSecondsLeft = Int(remaining.rounded(.up))
        progress = phaseTotal > 0 ? remaining / Double(phaseTotal) : 0

        if newSecondsLeft != secondsLeft {
            // Crossed a second boundary — emit a 3-2-1 tick if we're in the
            // last 3 seconds of an active phase.
            if newSecondsLeft < lastEmittedSecond,
               newSecondsLeft == 2 || newSecondsLeft == 1 {
                switch phase {
                case .countdown, .work, .rest:
                    audio.playCountdownTick(settings: audioSettings)
                case .finished:
                    break
                }
            }
            secondsLeft = newSecondsLeft
            lastEmittedSecond = newSecondsLeft

            if case .countdown = phase {
                phase = .countdown(newSecondsLeft)
            }
        }

        if remaining <= 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        switch phase {
        case .countdown:
            beginWork()
        case .work:
            // Final round: no trailing rest — go straight to finished.
            if currentRound >= workout.rounds {
                endRound()
            } else if workout.restSeconds > 0 {
                beginRest()
            } else {
                endRound()
            }
        case .rest:
            endRound()
        case .finished:
            break
        }
    }

    private func beginWork() {
        phase = .work
        phaseTotal = workout.workSeconds
        phaseStartedAt = .now
        phaseEndsAt = phaseStartedAt.addingTimeInterval(TimeInterval(phaseTotal))
        secondsLeft = phaseTotal
        lastEmittedSecond = phaseTotal
        progress = 1.0
        scheduleTimer()
        audio.playWorkStart(settings: audioSettings)
        pushActivityUpdate()
    }

    private func beginRest() {
        phase = .rest
        phaseTotal = workout.restSeconds
        phaseStartedAt = .now
        phaseEndsAt = phaseStartedAt.addingTimeInterval(TimeInterval(phaseTotal))
        secondsLeft = phaseTotal
        lastEmittedSecond = phaseTotal
        progress = 1.0
        scheduleTimer()
        audio.playRestStart(settings: audioSettings)
        pushActivityUpdate()
    }

    private func endRound() {
        if currentRound < workout.rounds {
            currentRound += 1
            beginWork()
        } else {
            phase = .finished
            tickTask?.cancel()
            progress = 0
            secondsLeft = 0
            audio.stopAmbient()
            audio.playFinished(settings: audioSettings)
            LiveActivityManager.shared.finish(round: currentRound)
        }
    }

    // MARK: - Live Activity bridge

    private var activityPhase: ActivityPhase {
        switch phase {
        case .countdown: .countdown
        case .work:      .work
        case .rest:      .rest
        case .finished:  .finished
        }
    }

    private func pushActivityUpdate() {
        guard !suppressActivityUpdates else { return }
        LiveActivityManager.shared.updatePhase(
            activityPhase,
            round: currentRound,
            start: phaseStartedAt,
            end: phaseEndsAt
        )
    }
}
