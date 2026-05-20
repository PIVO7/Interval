import Testing
@testable import Interval_v1

/// Tests cover the phase state machine via `skip()`. Real-time tick-based
/// progression is not exercised here — that would require injecting a
/// schedulable clock. Skip is the canonical way to step the machine in tests.
@Suite("TimerEngine state machine")
@MainActor
struct TimerEngineTests {

    private func makeEngine(
        workSeconds: Int = 30,
        restSeconds: Int = 15,
        rounds: Int = 8
    ) -> TimerEngine {
        let workout = Workout(
            name: "Test",
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds
        )
        return TimerEngine(workout: workout, audioSettings: AudioSettings())
    }

    private func isCountdown(_ phase: TrainingPhase) -> Bool {
        if case .countdown = phase { return true } else { return false }
    }
    private func isWork(_ phase: TrainingPhase) -> Bool {
        if case .work = phase { return true } else { return false }
    }
    private func isRest(_ phase: TrainingPhase) -> Bool {
        if case .rest = phase { return true } else { return false }
    }
    private func isFinished(_ phase: TrainingPhase) -> Bool {
        if case .finished = phase { return true } else { return false }
    }

    // MARK: - Initial state

    @Test("Starts in countdown(3) at round 1")
    func initialState() {
        let engine = makeEngine()
        #expect(isCountdown(engine.phase))
        #expect(engine.currentRound == 1)
        #expect(engine.secondsLeft == 3)
        #expect(engine.isPaused == false)
        #expect(engine.progress == 1.0)
    }

    // MARK: - Skip progression — standard workout

    @Test("Skip from countdown enters work at the configured duration")
    func skipCountdownToWork() {
        let engine = makeEngine(workSeconds: 30)
        engine.skip()
        #expect(isWork(engine.phase))
        #expect(engine.secondsLeft == 30)
        #expect(engine.currentRound == 1)
    }

    @Test("Skip work → rest when restSeconds > 0")
    func skipWorkToRest() {
        let engine = makeEngine(restSeconds: 15)
        engine.skip() // countdown -> work
        engine.skip() // work -> rest
        #expect(isRest(engine.phase))
        #expect(engine.secondsLeft == 15)
        #expect(engine.currentRound == 1)
    }

    @Test("Skip rest advances to next round and starts work")
    func skipRestAdvancesRound() {
        let engine = makeEngine()
        engine.skip() // countdown -> work (r1)
        engine.skip() // work -> rest
        engine.skip() // rest -> work (r2)
        #expect(isWork(engine.phase))
        #expect(engine.currentRound == 2)
    }

    // MARK: - rest = 0 edge case

    @Test("With rest=0, skip work goes directly to next round")
    func zeroRestSkipsRest() {
        let engine = makeEngine(restSeconds: 0)
        engine.skip() // countdown -> work (r1)
        engine.skip() // work -> work (r2), no rest in between
        #expect(isWork(engine.phase))
        #expect(engine.currentRound == 2)
    }

    @Test("With rest=0 on final round, work goes directly to finished")
    func zeroRestFinalRound() {
        let engine = makeEngine(restSeconds: 0, rounds: 2)
        engine.skip() // countdown -> work (r1)
        engine.skip() // work -> work (r2)
        engine.skip() // work (r2, final) -> finished
        #expect(isFinished(engine.phase))
    }

    // MARK: - Final round behaviour (the bug we just fixed)

    @Test("Final round work goes straight to finished — no trailing rest")
    func finalRoundNoTrailingRest() {
        let engine = makeEngine(restSeconds: 15, rounds: 2)
        engine.skip() // countdown -> work (r1)
        engine.skip() // work -> rest
        engine.skip() // rest -> work (r2)
        engine.skip() // work (r2, final) -> finished (NOT rest)
        #expect(isFinished(engine.phase))
    }

    @Test("Single-round workout with rest>0 finishes after one work period")
    func singleRoundWithRest() {
        let engine = makeEngine(restSeconds: 15, rounds: 1)
        engine.skip() // countdown -> work
        engine.skip() // work -> finished (no rest, only 1 round)
        #expect(isFinished(engine.phase))
    }

    @Test("Single-round workout with rest=0 finishes after one work period")
    func singleRoundNoRest() {
        let engine = makeEngine(restSeconds: 0, rounds: 1)
        engine.skip() // countdown -> work
        engine.skip() // work -> finished
        #expect(isFinished(engine.phase))
    }

    // MARK: - Full multi-round walk-through

    @Test("Full 3-round walk through has 3 work + 2 rest + finished")
    func fullThreeRoundWalk() {
        let engine = makeEngine(rounds: 3)

        engine.skip() // -> work r1
        #expect(isWork(engine.phase)); #expect(engine.currentRound == 1)

        engine.skip() // -> rest after r1
        #expect(isRest(engine.phase)); #expect(engine.currentRound == 1)

        engine.skip() // -> work r2
        #expect(isWork(engine.phase)); #expect(engine.currentRound == 2)

        engine.skip() // -> rest after r2
        #expect(isRest(engine.phase)); #expect(engine.currentRound == 2)

        engine.skip() // -> work r3
        #expect(isWork(engine.phase)); #expect(engine.currentRound == 3)

        engine.skip() // -> finished (no trailing rest)
        #expect(isFinished(engine.phase))
    }

    // MARK: - Pause / resume

    @Test("togglePause flips isPaused")
    func togglePause() {
        let engine = makeEngine()
        engine.skip() // get past initial countdown
        #expect(engine.isPaused == false)
        engine.togglePause()
        #expect(engine.isPaused == true)
        engine.togglePause()
        #expect(engine.isPaused == false)
    }

    @Test("Skip while paused still advances phase")
    func skipWhilePaused() {
        let engine = makeEngine(restSeconds: 15)
        engine.skip() // countdown -> work
        engine.togglePause()
        engine.skip() // work -> rest (even while paused)
        #expect(isRest(engine.phase))
    }

    // MARK: - Stop

    @Test("Stop preserves current phase but cancels the timer")
    func stopPreservesState() {
        let engine = makeEngine()
        engine.skip() // -> work
        let phaseBefore = engine.phase
        let roundBefore = engine.currentRound
        engine.stop()
        // Behaviour: stop just cancels the internal timer + ambient audio.
        // It does NOT reset state — that's the caller's job (typically by dismissing the view).
        #expect(engine.currentRound == roundBefore)
        if case .work = phaseBefore, case .work = engine.phase {
            // ok — both work
        } else {
            Issue.record("Phase should remain unchanged after stop")
        }
    }
}
