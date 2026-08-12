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
    var phase: TrainingPhase = .countdown(TimerEngine.countdownSeconds)
    var secondsLeft: Int = 0
    var currentRound: Int = 1
    var isPaused: Bool = false

    // MARK: - Config
    //
    // `workout` is mutable so users can fine-tune work/rest/rounds mid-session
    // (only while paused — see `updateWorkSeconds` etc.). The active phase
    // already running keeps its original duration; the new values take effect
    // from the next phase transition onward.
    var workout: Workout
    private let cues: CueOrchestrating

    /// Length of the "get ready" countdown before the first work block.
    /// Voice clips only exist for 3/2/1, so any value ≥3 counts down silently
    /// until the final three seconds, where the tick loop speaks 3-2-1.
    static let countdownSeconds = 5

    // MARK: - Adjustment limits
    static let minWorkSeconds = 5
    static let minRestSeconds = 0
    static let maxPhaseSeconds = 3600
    static let maxRounds = 99

    // MARK: - Wall-clock state
    //
    // `nonisolated(unsafe)` on `tickTask` lets `deinit` (which is implicitly
    // nonisolated under Swift 6 strict concurrency) call `cancel()` without
    // crossing the actor boundary. `Task.cancel()` itself is thread-safe.
    @ObservationIgnored private nonisolated(unsafe) var tickTask: Task<Void, Never>?
    @ObservationIgnored private var phaseTotal: Int = TimerEngine.countdownSeconds
    @ObservationIgnored private var phaseStartedAt: Date = .now
    @ObservationIgnored private var phaseEndsAt: Date = .now
    @ObservationIgnored private var pausedAt: Date?
    /// Tracks the last whole-second value emitted, so we only play 3-2-1
    /// countdown ticks once per second boundary regardless of tick rate.
    @ObservationIgnored private var lastEmittedSecond: Int = -1
    /// True while we're fast-forwarding through phase boundaries the app
    /// missed in the background. Suppresses the per-phase audio cues so
    /// users don't hear a rapid bell salvo for every phase they slept
    /// through — one final cue for the landing phase is enough.
    @ObservationIgnored private var isCatchingUp = false

    init(workout: Workout, cues: CueOrchestrating) {
        self.workout = workout
        self.cues = cues
        cues.prepareForWorkout()
        startCountdown()
    }

    deinit {
        tickTask?.cancel()
    }

    // MARK: - Public controls
    func togglePause() {
        if isPaused {
            // Resume — shift the schedule forward by the pause duration so
            // secondsLeft doesn't lurch.
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
    }

    func skip() {
        advancePhase()
        // Skipping while paused: the new phase was just anchored at .now,
        // but the pause started earlier. Without re-anchoring, resume would
        // shift the schedule by the FULL pause duration (including the time
        // before the skip), inflating the new phase — pause 60s, skip,
        // resume → up to 60s extra. Re-anchor the pause at the skip moment
        // so resume only compensates for time paused after it.
        if isPaused { pausedAt = .now }
    }

    /// Reset the engine for a fresh run of the same workout, called
    /// from the FinishedView's "Nogmaals" button. Audio session and
    /// channels stay alive (we deliberately didn't tear them down at
    /// `.finished`) so the restart is instant — no ducking flicker
    /// against background music.
    func restart() {
        tickTask?.cancel()
        currentRound = 1
        isPaused = false
        pausedAt = nil
        isCatchingUp = false
        startCountdown()
    }

    // MARK: - Mid-workout adjustments
    //
    // Only allowed while paused, and not during countdown/finished. The
    // currently running phase keeps its original duration so users don't
    // see a confusing jump; new values apply at the next phase transition.

    /// True when the engine is in a state that accepts work/rest/rounds edits.
    var canAdjust: Bool {
        guard isPaused else { return false }
        switch phase {
        case .work, .rest: return true
        case .countdown, .finished: return false
        }
    }

    func updateWorkSeconds(_ value: Int) {
        guard canAdjust else { return }
        let clamped = min(max(value, Self.minWorkSeconds), Self.maxPhaseSeconds)
        workout.workSeconds = clamped
    }

    func updateRestSeconds(_ value: Int) {
        guard canAdjust else { return }
        let clamped = min(max(value, Self.minRestSeconds), Self.maxPhaseSeconds)
        workout.restSeconds = clamped
    }

    /// Adjust total rounds. Lower bound is `currentRound` so we can never
    /// drop below the round the user is in — that would be an impossible
    /// state for the phase machine.
    func updateRounds(_ value: Int) {
        guard canAdjust else { return }
        let floor = max(currentRound, 1)
        let clamped = min(max(value, floor), Self.maxRounds)
        workout.rounds = clamped
    }

    func stop() {
        tickTask?.cancel()
        cues.workoutDidEnd()
    }

    /// Wall-clock-driven progress for the current phase, sampled at a given
    /// instant. Lets the ring render via `TimelineView(.animation)` so it
    /// stays perfectly in sync (no animation lag, fully closes before the
    /// phase advances).
    func progress(at date: Date) -> Double {
        if isFinished { return 0 }
        let reference = pausedAt ?? date
        let remaining = max(0, phaseEndsAt.timeIntervalSince(reference))
        return phaseTotal > 0 ? remaining / Double(phaseTotal) : 0
    }

    /// Called when the app returns to the foreground — fast-forward through
    /// any phase boundaries that completed while we were suspended, then
    /// emit a single audio cue for the phase the user actually landed in.
    func recomputeFromWallClock() {
        guard !isPaused else { return }
        isCatchingUp = true
        defer { isCatchingUp = false }
        var didAdvance = false
        var guardCounter = 0
        let maxIterations = max(8, workout.rounds * 2 + 4)
        while !isFinished, Date.now >= phaseEndsAt, guardCounter < maxIterations {
            // Anchor the next phase to the moment the current one truly
            // ended, not `Date.now` — otherwise each catch-up step would
            // reset the timeline and we'd only ever advance one phase.
            let transitionedAt = phaseEndsAt
            advancePhase(at: transitionedAt)
            didAdvance = true
            guardCounter += 1
        }
        if didAdvance {
            // Reset before emitting so the cue actually fires, and emit one
            // sound for the landing phase. `.finished` skips it — the
            // finished view is loud enough on its own.
            isCatchingUp = false
            switch phase {
            case .work:
                cues.emit(workStartCue)
            case .rest:
                cues.emit(.restStart)
            case .countdown, .finished:
                break
            }
        }
        tick()
    }

    // MARK: - Private
    private var isFinished: Bool {
        if case .finished = phase { true } else { false }
    }

    /// Cue to emit when entering a work block. Replaces `.workStart`
    /// with `.lastRound` on the final round (rounds ≥ 2) and
    /// `.halfway` on the midpoint round (rounds ≥ 4). Both lookups
    /// fall back to `.workStart` when the conditions don't apply.
    /// `.lastRound` wins if both would trigger on the same round
    /// (rare; happens only at very small round counts where the
    /// formulas collide).
    private var workStartCue: WorkoutCue {
        if workout.rounds >= 2, currentRound == workout.rounds {
            return .lastRound
        }
        // Halfway round = ⌊rounds/2⌋ + 1. For rounds=4 → round 3,
        // for rounds=8 → round 5, for rounds=5 → round 3. The
        // `rounds >= 4` guard keeps tiny workouts from emitting a
        // "halfway" cue that would feel premature (e.g. fire on
        // round 2 of 3).
        let halfwayRound = workout.rounds / 2 + 1
        if workout.rounds >= 4, currentRound == halfwayRound {
            return .halfway
        }
        return .workStart
    }

    private func startCountdown() {
        let total = Self.countdownSeconds
        phase = .countdown(total)
        phaseTotal = total
        phaseStartedAt = .now
        phaseEndsAt = phaseStartedAt.addingTimeInterval(TimeInterval(total))
        secondsLeft = total
        lastEmittedSecond = total
        scheduleTimer()
        // No explicit start cue: the countdown is silent until the tick loop
        // crosses into the final three seconds, where it speaks 3-2-1 (there
        // are no voice clips for 5/4). See tick().
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

        if newSecondsLeft != secondsLeft {
            // Crossed a second boundary — emit a 3-2-1 voice cue if we're
            // in the last 3 seconds of an active phase.
            if newSecondsLeft < lastEmittedSecond,
               (1...3).contains(newSecondsLeft) {
                switch phase {
                case .countdown, .work, .rest:
                    cues.emit(.countdownTick(secondsLeft: newSecondsLeft))
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

    /// Advance to the next phase. `at` is the wall-clock moment the new
    /// phase should be anchored to — defaults to `.now` for live ticks,
    /// but foreground catch-up passes the previous `phaseEndsAt` so a
    /// chain of missed phases cascades through their real timing.
    private func advancePhase(at startedAt: Date = .now) {
        switch phase {
        case .countdown:
            beginWork(at: startedAt)
        case .work:
            // Final round: no trailing rest — go straight to finished.
            if currentRound >= workout.rounds {
                endRound(at: startedAt)
            } else if workout.restSeconds > 0 {
                beginRest(at: startedAt)
            } else {
                endRound(at: startedAt)
            }
        case .rest:
            endRound(at: startedAt)
        case .finished:
            break
        }
    }

    private func beginWork(at startedAt: Date = .now) {
        phase = .work
        phaseTotal = workout.workSeconds
        phaseStartedAt = startedAt
        phaseEndsAt = startedAt.addingTimeInterval(TimeInterval(phaseTotal))
        secondsLeft = phaseTotal
        lastEmittedSecond = phaseTotal
        scheduleTimer()
        if !isCatchingUp {
            cues.emit(workStartCue)
        }
    }

    private func beginRest(at startedAt: Date = .now) {
        phase = .rest
        phaseTotal = workout.restSeconds
        phaseStartedAt = startedAt
        phaseEndsAt = startedAt.addingTimeInterval(TimeInterval(phaseTotal))
        secondsLeft = phaseTotal
        lastEmittedSecond = phaseTotal
        scheduleTimer()
        if !isCatchingUp {
            cues.emit(.restStart)
        }
    }

    private func endRound(at startedAt: Date = .now) {
        if currentRound < workout.rounds {
            currentRound += 1
            beginWork(at: startedAt)
        } else {
            phase = .finished
            tickTask?.cancel()
            secondsLeft = 0
            if !isCatchingUp {
                cues.emit(.finished)
            }
            // Do NOT call `cues.workoutDidEnd()` here — that immediately
            // stops the audio engine, cutting the just-scheduled "finished"
            // cue mid-playback. Lifecycle teardown happens via `stop()`,
            // called from `ActiveTrainingView.onDisappear` when the user
            // dismisses the finished screen. The session stays active
            // until then so the celebratory cue gets to play out fully.
        }
    }
}
