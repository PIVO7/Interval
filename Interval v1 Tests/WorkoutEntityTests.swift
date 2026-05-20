import Testing
import Foundation
@testable import Interval_v1

@Suite("WorkoutEntity ↔ Workout conversion")
struct WorkoutEntityTests {

    @Test("Entity preserves all fields from Workout")
    func entityFromWorkout() {
        let original = Workout(
            id: UUID(),
            name: "Tabata 30/15",
            workSeconds: 30,
            restSeconds: 15,
            rounds: 8,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let entity = WorkoutEntity(from: original)

        #expect(entity.id == original.id)
        #expect(entity.name == original.name)
        #expect(entity.workSeconds == original.workSeconds)
        #expect(entity.restSeconds == original.restSeconds)
        #expect(entity.rounds == original.rounds)
        #expect(entity.createdAt == original.createdAt)
    }

    @Test("Round-trip Workout → Entity → Workout is lossless")
    func roundTrip() {
        let original = Workout(
            id: UUID(),
            name: "HIIT 40/20",
            workSeconds: 40,
            restSeconds: 20,
            rounds: 10,
            createdAt: Date()
        )
        let back = WorkoutEntity(from: original).toWorkout()

        #expect(back.id == original.id)
        #expect(back.name == original.name)
        #expect(back.workSeconds == original.workSeconds)
        #expect(back.restSeconds == original.restSeconds)
        #expect(back.rounds == original.rounds)
        #expect(back.createdAt == original.createdAt)
        #expect(back.totalSeconds == original.totalSeconds)
    }

    @Test("Entity summary matches Workout summary")
    func summaryParity() {
        let original = Workout(name: "X", workSeconds: 25, restSeconds: 10, rounds: 6)
        let entity = WorkoutEntity(from: original)
        #expect(entity.summary == original.summary)
    }
}
