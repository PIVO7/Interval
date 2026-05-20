import Testing
@testable import Interval_v1

@Suite("Workout model")
struct WorkoutTests {

    @Test("Tabata 30/15 × 8 totals work + 7 rest periods")
    func tabataTotal() {
        let w = Workout(name: "Tabata", workSeconds: 30, restSeconds: 15, rounds: 8)
        // 8 work + 7 rest (no rest after final work)
        #expect(w.totalSeconds == 8 * 30 + 7 * 15)
    }

    @Test("Rest = 0 leaves only work duration")
    func zeroRestTotal() {
        let w = Workout(name: "Continuous", workSeconds: 60, restSeconds: 0, rounds: 5)
        #expect(w.totalSeconds == 5 * 60)
    }

    @Test("Single round = work only (no rest period at all)")
    func singleRoundTotal() {
        let w = Workout(name: "Single", workSeconds: 45, restSeconds: 30, rounds: 1)
        #expect(w.totalSeconds == 45)
    }

    @Test("Very long work duration multiplies correctly")
    func longWorkout() {
        let w = Workout(name: "Long", workSeconds: 600, restSeconds: 120, rounds: 10)
        #expect(w.totalSeconds == 10 * 600 + 9 * 120)
    }

    @Test("Summary mentions work, rest and rounds")
    func summaryFormat() {
        let w = Workout(name: "X", workSeconds: 30, restSeconds: 15, rounds: 8)
        let s = w.summary
        #expect(s.contains("30"))
        #expect(s.contains("15"))
        #expect(s.contains("8"))
    }

    @Test("Equal Workout instances have equal seconds-derived fields")
    func equivalence() {
        let a = Workout(name: "A", workSeconds: 30, restSeconds: 15, rounds: 8)
        let b = Workout(name: "B", workSeconds: 30, restSeconds: 15, rounds: 8)
        #expect(a.totalSeconds == b.totalSeconds)
        #expect(a.summary == b.summary)
    }
}
