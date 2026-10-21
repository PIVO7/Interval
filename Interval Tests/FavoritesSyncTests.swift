import Testing
import Foundation
import SwiftData
@testable import Interval

@Suite("FavoritesSync queue + reconciliation")
@MainActor
struct FavoritesSyncTests {

    /// In-memory stand-in for Supabase. `offline` makes every call fail
    /// like a dropped connection; `signedOut` like guest mode.
    @MainActor
    final class FakeRemote: FavoritesRemote {
        var rows: [UUID: RemoteWorkout] = [:]
        var offline = false
        var signedOut = false
        /// Server clock used to stamp `updated_at` on upsert.
        var serverNow = Date(timeIntervalSince1970: 2_000_000)
        private(set) var upsertCount = 0

        private func check() throws {
            if signedOut { throw SupabaseError.notSignedIn }
            if offline { throw URLError(.notConnectedToInternet) }
        }

        func fetchWorkouts() async throws -> [RemoteWorkout] {
            try check()
            return Array(rows.values)
        }

        func upsertWorkout(_ workout: Workout) async throws {
            try check()
            upsertCount += 1
            serverNow += 1
            rows[workout.id] = RemoteWorkout(workout: workout, updatedAt: serverNow)
        }

        func deleteWorkout(id: UUID) async throws {
            try check()
            rows[id] = nil
        }
    }

    /// Keeps the container alive for the duration of a test.
    @MainActor
    struct Fixture {
        let container: ModelContainer
        let remote: FakeRemote
        let sync: FavoritesSync

        var context: ModelContext { container.mainContext }

        func locals() throws -> [WorkoutEntity] {
            try context.fetch(FetchDescriptor<WorkoutEntity>())
        }

        func local(_ id: UUID) throws -> WorkoutEntity? {
            try locals().first { $0.id == id }
        }
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: WorkoutEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let remote = FakeRemote()
        let defaults = try #require(UserDefaults(suiteName: "FavoritesSyncTests-\(UUID().uuidString)"))
        let sync = FavoritesSync(
            context: container.mainContext,
            remote: remote,
            defaults: defaults,
            syncsAutomatically: false
        )
        return Fixture(container: container, remote: remote, sync: sync)
    }

    private func workout(_ name: String = "Tabata") -> Workout {
        Workout(name: name, workSeconds: 30, restSeconds: 15, rounds: 8,
                createdAt: Date(timeIntervalSince1970: 1_000_000))
    }

    /// Seed a favorite that both sides already agree on.
    private func seedSynced(_ w: Workout, at date: Date, in f: Fixture) throws {
        f.remote.rows[w.id] = RemoteWorkout(workout: w, updatedAt: date)
        f.context.insert(WorkoutEntity(from: w, updatedAt: date, needsUpload: false))
        try f.context.save()
    }

    // MARK: - Pending uploads

    @Test("A failed upload stays queued and is retried on the next pass")
    func failedUploadIsRetried() async throws {
        let f = try makeFixture()
        let w = workout()
        f.remote.offline = true
        try f.sync.saveNew(w)
        await f.sync.sync()

        #expect(f.remote.rows.isEmpty)
        #expect(try f.local(w.id)?.needsUpload == true)

        f.remote.offline = false
        await f.sync.sync()

        #expect(f.remote.rows[w.id]?.workout.name == w.name)
        #expect(try f.local(w.id)?.needsUpload == false)
    }

    @Test("Guest mode keeps changes queued without touching the server")
    func signedOutKeepsQueue() async throws {
        let f = try makeFixture()
        let w = workout()
        f.remote.signedOut = true
        try f.sync.saveNew(w)
        await f.sync.sync()

        #expect(f.remote.upsertCount == 0)
        #expect(try f.local(w.id)?.needsUpload == true)
    }

    // MARK: - Conflicts

    @Test("An older server copy doesn't overwrite a newer offline edit")
    func newerLocalEditWins() async throws {
        let f = try makeFixture()
        let t0 = Date(timeIntervalSince1970: 1_500_000)
        let w = workout("Original")
        try seedSynced(w, at: t0, in: f)

        let entity = try #require(try f.local(w.id))
        entity.name = "Edited offline"
        entity.markEdited(at: t0 + 60)
        try f.context.save()

        await f.sync.sync()

        #expect(try f.local(w.id)?.name == "Edited offline")
        #expect(try f.local(w.id)?.needsUpload == false)
        #expect(f.remote.rows[w.id]?.workout.name == "Edited offline")
    }

    @Test("A newer server edit wins over an older unpushed local edit")
    func newerRemoteEditWins() async throws {
        let f = try makeFixture()
        let t0 = Date(timeIntervalSince1970: 1_500_000)
        let w = workout("Original")
        try seedSynced(w, at: t0, in: f)

        let entity = try #require(try f.local(w.id))
        entity.name = "Older local edit"
        entity.markEdited(at: t0 + 10)
        try f.context.save()

        var remoteEdit = w
        remoteEdit.name = "Newer remote edit"
        f.remote.rows[w.id] = RemoteWorkout(workout: remoteEdit, updatedAt: t0 + 20)

        await f.sync.sync()

        #expect(try f.local(w.id)?.name == "Newer remote edit")
        #expect(try f.local(w.id)?.needsUpload == false)
        #expect(f.remote.rows[w.id]?.workout.name == "Newer remote edit")
        #expect(f.remote.upsertCount == 0)
    }

    @Test("Remote edits replace synced local copies")
    func remoteEditAppliesToSyncedCopy() async throws {
        let f = try makeFixture()
        let t0 = Date(timeIntervalSince1970: 1_500_000)
        let w = workout("Original")
        try seedSynced(w, at: t0, in: f)

        var remoteEdit = w
        remoteEdit.rounds = 12
        f.remote.rows[w.id] = RemoteWorkout(workout: remoteEdit, updatedAt: t0 + 5)

        await f.sync.sync()

        #expect(try f.local(w.id)?.rounds == 12)
    }

    // MARK: - Deletions

    @Test("A favorite deleted on another device is removed locally")
    func remoteDeletionPropagates() async throws {
        let f = try makeFixture()
        let w = workout()
        try seedSynced(w, at: Date(timeIntervalSince1970: 1_500_000), in: f)

        f.remote.rows[w.id] = nil // deleted elsewhere
        await f.sync.sync()

        #expect(try f.local(w.id) == nil)
        #expect(f.remote.upsertCount == 0) // not re-uploaded
    }

    @Test("A local-only favorite is uploaded, not treated as deleted elsewhere")
    func localOnlyFavoriteIsKept() async throws {
        let f = try makeFixture()
        let w = workout()
        try f.sync.saveNew(w)

        await f.sync.sync()

        #expect(try f.local(w.id) != nil)
        #expect(f.remote.rows[w.id] != nil)
    }

    @Test("Rows from before sync tracking upload unless the server has them")
    func migratedRowsAreSafe() async throws {
        let f = try makeFixture()
        // Mirrors the migration defaults: distantPast + pending.
        let onlyLocal = workout("Only local")
        let alsoRemote = workout("Also remote")
        f.context.insert(WorkoutEntity(from: onlyLocal, updatedAt: .distantPast, needsUpload: true))
        f.context.insert(WorkoutEntity(from: alsoRemote, updatedAt: .distantPast, needsUpload: true))
        try f.context.save()
        var serverCopy = alsoRemote
        serverCopy.name = "Server name"
        f.remote.rows[alsoRemote.id] = RemoteWorkout(workout: serverCopy, updatedAt: Date(timeIntervalSince1970: 1_500_000))

        await f.sync.sync()

        #expect(f.remote.rows[onlyLocal.id] != nil)
        #expect(try f.local(alsoRemote.id)?.name == "Server name")
    }

    @Test("An offline delete isn't resurrected and is pushed later")
    func offlineDeleteIsQueued() async throws {
        let f = try makeFixture()
        let w = workout()
        try seedSynced(w, at: Date(timeIntervalSince1970: 1_500_000), in: f)

        f.remote.offline = true
        try f.sync.delete(try #require(try f.local(w.id)))
        await f.sync.sync()
        #expect(f.remote.rows[w.id] != nil) // couldn't reach the server

        f.remote.offline = false
        await f.sync.sync()

        #expect(f.remote.rows[w.id] == nil)
        #expect(try f.local(w.id) == nil)
        #expect(f.remote.upsertCount == 0)
    }
}
