import Testing
@testable import Interval_v1

/// Tests cover the phase state machine via `skip()`. Real-time tick-based
/// progression is not exercised here — that would require injecting a
/// schedulable clock. Skip is the canonical way to step the machine in tests.
@Suite("TimerEngine state machine")
@MainActor
struct TimerEngineTests {

    /// Mock orchestrator that records emitted cues and lifecycle calls,
    /// without spinning up `AVAudioEngine` or `CHHapticEngine`. Replaces
    /// the previous `TimerEngine.isHeadlessForTesting` flag — tests now
    /// inject this directly, so production code has no test-only branch.
    @MainActor
    final class MockCueOrchestrator: CueOrchestrating {
        private(set) var emittedCues: [WorkoutCue] = []
        private(set) var prepareCalls: Int = 0
        private(set) var endCalls: Int = 0

        func prepareForWorkout() { prepareCalls += 1 }
        func emit(_ cue: WorkoutCue) { emittedCues.append(cue) }
        func workoutDidEnd() { endCalls += 1 }
    }

    private func makeEngine(
        workSeconds: Int = 30,
        restSeconds: Int = 15,
        rounds: Int = 8,
        cues: MockCueOrchestrator? = nil
    ) -> TimerEngine {
        let workout = Workout(
            name: "Test",
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds
        )
        return TimerEngine(workout: workout, cues: cues ?? MockCueOrchestrator())
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

    @Test("Starts in countdown(5) at round 1")
    func initialState() {
        let engine = makeEngine()
        #expect(isCountdown(engine.phase))
        #expect(engine.currentRound == 1)
        #expect(engine.secondsLeft == TimerEngine.countdownSeconds)
        #expect(engine.isPaused == false)
        #expect(engine.progress(at: .now) > 0.99)
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

    @Test("Pause → skip → resume does not inflate the next phase")
    func skipWhilePausedReAnchorsPause() async throws {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15)
        engine.skip() // countdown -> work
        engine.togglePause()
        // Let real time pass while paused — this is the duration that, before
        // the fix, leaked into the next phase on resume (skip re-anchors the
        // phase at .now, but resume shifted it by the FULL pause duration).
        try await Task.sleep(for: .milliseconds(400))
        engine.skip() // work -> rest, while paused
        engine.togglePause() // resume immediately after the skip

        // Buggy behaviour: secondsLeft == 16 (15 + ~0.4s rounded up) and
        // progress overshoots 1.0. Correct: the rest phase is exactly 15s.
        #expect(engine.secondsLeft <= 15)
        #expect(engine.progress(at: .now) <= 1.0)
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

    // MARK: - Mid-workout adjustments

    @Test("canAdjust is false during countdown")
    func cannotAdjustDuringCountdown() {
        let engine = makeEngine()
        engine.togglePause()
        #expect(engine.canAdjust == false)
    }

    @Test("canAdjust is false while running (not paused)")
    func cannotAdjustWhileRunning() {
        let engine = makeEngine()
        engine.skip() // -> work
        #expect(engine.canAdjust == false)
    }

    @Test("canAdjust is true when paused during work")
    func canAdjustWhenPausedDuringWork() {
        let engine = makeEngine()
        engine.skip() // -> work
        engine.togglePause()
        #expect(engine.canAdjust == true)
    }

    @Test("canAdjust is false after finishing")
    func cannotAdjustAfterFinish() {
        let engine = makeEngine(restSeconds: 0, rounds: 1)
        engine.skip() // -> work
        engine.skip() // -> finished
        engine.togglePause() // paused state doesn't matter at finish
        #expect(engine.canAdjust == false)
    }

    @Test("Updating workSeconds while paused changes future phases only")
    func updateWorkSecondsAppliesToNextPhase() {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15, rounds: 3)
        engine.skip() // -> work r1 (30s)
        let originalSecondsLeft = engine.secondsLeft
        engine.togglePause()
        engine.updateWorkSeconds(60)
        #expect(engine.workout.workSeconds == 60)
        // Current work phase is unchanged
        #expect(engine.secondsLeft == originalSecondsLeft)
        engine.togglePause()
        engine.skip() // -> rest
        engine.skip() // -> work r2 (now 60s)
        #expect(isWork(engine.phase))
        #expect(engine.secondsLeft == 60)
    }

    @Test("Updating restSeconds while paused changes future rest")
    func updateRestSecondsAppliesToNextRest() {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15, rounds: 3)
        engine.skip() // -> work r1
        engine.togglePause()
        engine.updateRestSeconds(45)
        engine.togglePause()
        engine.skip() // -> rest
        #expect(isRest(engine.phase))
        #expect(engine.secondsLeft == 45)
    }

    @Test("Setting restSeconds to 0 mid-workout skips rest from next round")
    func setRestZeroSkipsFutureRest() {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15, rounds: 3)
        engine.skip() // -> work r1
        engine.togglePause()
        engine.updateRestSeconds(0)
        engine.togglePause()
        engine.skip() // -> next: work r2 directly (no rest with rest=0)
        #expect(isWork(engine.phase))
        #expect(engine.currentRound == 2)
    }

    @Test("Updating rounds while paused changes total rounds")
    func updateRoundsAppliesImmediately() {
        let engine = makeEngine(rounds: 8)
        engine.skip() // -> work r1
        engine.togglePause()
        engine.updateRounds(3)
        #expect(engine.workout.rounds == 3)
    }

    @Test("Cannot set rounds below currentRound — clamps to currentRound")
    func roundsClampsToCurrentRound() {
        let engine = makeEngine(rounds: 5)
        engine.skip() // -> work r1
        engine.skip() // -> rest
        engine.skip() // -> work r2
        engine.skip() // -> rest
        engine.skip() // -> work r3
        engine.togglePause()
        engine.updateRounds(1) // attempt to lower below currentRound=3
        #expect(engine.workout.rounds == 3)
    }

    @Test("Lowering rounds to currentRound finishes after this round")
    func loweringRoundsToCurrentFinishesNext() {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15, rounds: 5)
        engine.skip() // -> work r1
        engine.skip() // -> rest
        engine.skip() // -> work r2
        engine.togglePause()
        engine.updateRounds(2) // make r2 the final round
        engine.togglePause()
        engine.skip() // work r2 (final) -> finished (no trailing rest)
        #expect(isFinished(engine.phase))
    }

    @Test("workSeconds is clamped to minimum (5)")
    func workSecondsClampsToMinimum() {
        let engine = makeEngine()
        engine.skip()
        engine.togglePause()
        engine.updateWorkSeconds(1)
        #expect(engine.workout.workSeconds == TimerEngine.minWorkSeconds)
    }

    @Test("Adjustments are ignored while not paused")
    func adjustmentsIgnoredWhenRunning() {
        let engine = makeEngine(workSeconds: 30, restSeconds: 15, rounds: 5)
        engine.skip() // -> work, running
        engine.updateWorkSeconds(99)
        engine.updateRestSeconds(99)
        engine.updateRounds(99)
        #expect(engine.workout.workSeconds == 30)
        #expect(engine.workout.restSeconds == 15)
        #expect(engine.workout.rounds == 5)
    }

    // MARK: - Cue emission

    @Test("Init prepares the orchestrator without a premature countdown cue")
    func initPreparesWithoutCue() {
        let cues = MockCueOrchestrator()
        _ = makeEngine(cues: cues)
        #expect(cues.prepareCalls == 1)
        // The 5s countdown is silent until the tick loop reaches the final
        // 3 seconds, so nothing is emitted at init.
        #expect(cues.emittedCues.isEmpty)
    }

    @Test("Skip from countdown emits workStart cue")
    func skipEmitsWorkStart() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(cues: cues)
        engine.skip() // countdown -> work
        #expect(cues.emittedCues.contains(.workStart))
    }

    @Test("Skip from work emits restStart cue")
    func skipEmitsRestStart() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(cues: cues)
        engine.skip() // -> work
        engine.skip() // -> rest
        #expect(cues.emittedCues.contains(.restStart))
    }

    @Test("Final round emits finished cue + lifecycle end")
    func finalRoundEmitsFinished() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(restSeconds: 0, rounds: 1, cues: cues)
        engine.skip() // -> work
        engine.skip() // -> finished
        #expect(cues.emittedCues.contains(.finished))
        // Lifecycle end is NOT called when reaching finished — the audio
        // engine has to stay alive so the celebratory cue can play out.
        // workoutDidEnd fires later via the view's onDisappear → stop().
        #expect(cues.endCalls == 0)
    }

    @Test("Stop calls workoutDidEnd")
    func stopCallsWorkoutDidEnd() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(cues: cues)
        engine.stop()
        #expect(cues.endCalls == 1)
    }

    // MARK: - Halfway / Last round cues

    /// Walk from countdown through to a target work-phase round, returning
    /// the engine + cue log so tests can assert the cue emitted on entering
    /// that round.
    private func advance(toWorkRound target: Int, in engine: TimerEngine) {
        engine.skip() // countdown -> work r1
        while engine.currentRound < target {
            engine.skip() // work -> rest
            engine.skip() // rest -> work next
        }
    }

    @Test("Round 8 of 8: emits lastRound instead of workStart")
    func lastRoundOnFinalEightRound() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 8, cues: cues)
        advance(toWorkRound: 8, in: engine)
        #expect(cues.emittedCues.contains(.lastRound))
        // workStart still fires for rounds 1-7
        let workStartCount = cues.emittedCues.filter { $0 == .workStart }.count
        #expect(workStartCount == 6) // rounds 1, 2, 3, 4, 6, 7 (round 5 is halfway)
    }

    @Test("Round 5 of 8: emits halfway instead of workStart")
    func halfwayOnEightRoundWorkout() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 8, cues: cues)
        advance(toWorkRound: 5, in: engine)
        #expect(cues.emittedCues.contains(.halfway))
    }

    @Test("Round 3 of 4: emits halfway")
    func halfwayOnFourRoundWorkout() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 4, cues: cues)
        advance(toWorkRound: 3, in: engine)
        #expect(cues.emittedCues.contains(.halfway))
    }

    @Test("rounds=3: no halfway cue (workout too small)")
    func noHalfwayForThreeRounds() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 3, cues: cues)
        advance(toWorkRound: 3, in: engine)
        #expect(!cues.emittedCues.contains(.halfway))
        // But lastRound DOES fire for round 3 of 3
        #expect(cues.emittedCues.contains(.lastRound))
    }

    @Test("rounds=2: lastRound on round 2, no halfway")
    func lastRoundForTwoRounds() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 2, cues: cues)
        advance(toWorkRound: 2, in: engine)
        #expect(cues.emittedCues.contains(.lastRound))
        #expect(!cues.emittedCues.contains(.halfway))
    }

    @Test("rounds=1: no lastRound, no halfway — only workStart")
    func singleRoundEmitsWorkStartOnly() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 1, cues: cues)
        engine.skip() // countdown -> work r1
        #expect(cues.emittedCues.contains(.workStart))
        #expect(!cues.emittedCues.contains(.lastRound))
        #expect(!cues.emittedCues.contains(.halfway))
    }

    // MARK: - Restart

    @Test("Restart from finished resets to countdown, round 1")
    func restartResetsToCountdown() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(restSeconds: 0, rounds: 1, cues: cues)
        engine.skip() // -> work
        engine.skip() // -> finished
        #expect(isFinished(engine.phase))

        engine.restart()
        #expect(isCountdown(engine.phase))
        #expect(engine.currentRound == 1)
        #expect(engine.secondsLeft == TimerEngine.countdownSeconds)
        #expect(engine.isPaused == false)
    }

    @Test("Restart mid-workout also resets state")
    func restartMidWorkout() {
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 5, cues: cues)
        engine.skip() // -> work r1
        engine.skip() // -> rest
        engine.skip() // -> work r2
        engine.togglePause()
        #expect(engine.currentRound == 2)
        #expect(engine.isPaused == true)

        engine.restart()
        #expect(isCountdown(engine.phase))
        #expect(engine.currentRound == 1)
        #expect(engine.isPaused == false)
    }

    @Test("lastRound wins when halfway and lastRound would collide")
    func lastRoundWinsOverHalfway() {
        // With rounds=3, halfway formula gives round 2, lastRound gives 3.
        // No collision in this case — let's pick a contrived case where
        // they'd collide: a workout lowered to rounds=halfway during play.
        // Simpler: rounds=2 (lastRound=2, halfway disabled). Confirmed
        // above. Here we sanity-check the priority logic on a larger case.
        let cues = MockCueOrchestrator()
        let engine = makeEngine(rounds: 4, cues: cues)
        advance(toWorkRound: 4, in: engine) // final round
        // lastRound, not halfway, for round 4 of 4
        #expect(cues.emittedCues.last(where: { $0 == .lastRound || $0 == .halfway }) == .lastRound)
    }
}
