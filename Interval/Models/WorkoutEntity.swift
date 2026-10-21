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
    /// When this favorite's content last changed — a local edit, or the
    /// server's `updated_at` once a remote copy has been applied. Used by
    /// `FavoritesSync` for last-writer-wins when both sides changed.
    ///
    /// The declaration defaults matter for the lightweight migration of
    /// rows saved before sync tracking existed: `distantPast` + pending
    /// means "push me unless the server already has a copy", so a favorite
    /// whose earlier upload failed is uploaded instead of being treated
    /// as deleted elsewhere.
    var updatedAt: Date = Date.distantPast
    /// True while this favorite has local changes the server hasn't
    /// acknowledged yet (saved offline, upload failed, or guest mode).
    /// Cleared only after a successful upload, so a failed upload is
    /// retried on the next sync pass instead of being lost.
    var needsUpload: Bool = true

    init(
        id: UUID = UUID(),
        name: String,
        workSeconds: Int,
        restSeconds: Int,
        rounds: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        needsUpload: Bool = true
    ) {
        self.id = id
        self.name = name
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.rounds = rounds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsUpload = needsUpload
    }

    convenience init(from workout: Workout, updatedAt: Date = .now, needsUpload: Bool = true) {
        self.init(
            id: workout.id,
            name: workout.name,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            rounds: workout.rounds,
            createdAt: workout.createdAt,
            updatedAt: updatedAt,
            needsUpload: needsUpload
        )
    }

    /// Stamp a local edit so the next sync pass uploads it.
    func markEdited(at date: Date = .now) {
        updatedAt = date
        needsUpload = true
    }

    /// Overwrite the content fields with a copy from the server.
    func apply(_ workout: Workout) {
        name = workout.name
        workSeconds = workout.workSeconds
        restSeconds = workout.restSeconds
        rounds = workout.rounds
        createdAt = workout.createdAt
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
