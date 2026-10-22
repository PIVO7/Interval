import Foundation
import SwiftData

/// A saved favorite. Synced across the user's devices by SwiftData's
/// CloudKit integration, which sets the shape of this model: no
/// `@Attribute(.unique)` (CloudKit can't enforce it) and a default value
/// on every stored property. New favorites always get a fresh `id`
/// (see SaveFavoriteSheet), so dropping `.unique` doesn't create duplicates.
@Model
final class WorkoutEntity {
    var id: UUID = UUID()
    var name: String = ""
    var workSeconds: Int = 30
    var restSeconds: Int = 15
    var rounds: Int = 8
    var createdAt: Date = Date.now

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
