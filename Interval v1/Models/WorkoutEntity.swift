import Foundation
import SwiftData

@Model
final class WorkoutEntity {
    /// `.unique` so an import path that re-inserts a Workout already in
    /// the store (e.g. fetching from Supabase after a local save round
    /// trip) updates in place instead of producing a duplicate row.
    @Attribute(.unique) var id: UUID
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        workSeconds: Int,
        restSeconds: Int,
        rounds: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.createdAt = createdAt
    }

    convenience init(from workout: Workout) {
        self.init(
            id: workout.id,
            name: workout.name,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            rounds: workout.rounds,
            createdAt: workout.createdAt
        )
    }

    func toWorkout() -> Workout {
        Workout(
            id: id,
            name: name,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            rounds: rounds,
            createdAt: createdAt
        )
    }

    var summary: String {
        toWorkout().summary
    }
}
