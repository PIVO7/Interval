import Foundation
import Observation
import SwiftData
import os

/// A favorite as the server knows it, with the server's last-modified time.
struct RemoteWorkout {
    var workout: Workout
    var updatedAt: Date
}

/// The remote side of favorites sync. `SupabaseManager` in the app; a
/// fake in tests.
@MainActor
protocol FavoritesRemote {
    func fetchWorkouts() async throws -> [RemoteWorkout]
    func upsertWorkout(_ workout: Workout) async throws
    func deleteWorkout(id: UUID) async throws
}

extension SupabaseManager: FavoritesRemote {}

/// Keeps local favorites (SwiftData) and the server in step.
///
/// Local writes never wait on the network. Each change is recorded first —
/// `WorkoutEntity.needsUpload` for saves/edits, a persisted tombstone for
/// deletes — and a sync pass then works the queue off. Anything that fails
/// stays queued and is retried on the next pass (launch, sign-in, return to
/// foreground, or the next local change).
///
/// A pass runs in this order:
/// 1. Push queued deletes, so the fetch below can't resurrect them.
/// 2. Fetch every remote favorite.
/// 3. Reconcile: remote copies replace local ones unless the local copy has
///    a newer unpushed edit (last writer wins on `updatedAt`); favorites that
///    were synced before but are gone from the server were deleted on
///    another device and are removed here too.
/// 4. Push remaining local changes.
///
/// If the fetch fails nothing is pushed, so a stale local copy can't
/// overwrite a newer server edit blind.
@MainActor
@Observable
final class FavoritesSync {
    static let pendingDeletionsKey = "favorites_pending_deletions"

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let remote: FavoritesRemote
    @ObservationIgnored private let defaults: UserDefaults
    /// When false, local changes don't kick off a pass on their own — tests
    /// call `sync()` explicitly so passes don't race the assertions.
    @ObservationIgnored private let syncsAutomatically: Bool
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var needsAnotherPass = false
    @ObservationIgnored private let log = Logger(subsystem: "com.superapp.interval", category: "Sync")

    init(
        context: ModelContext,
        remote: FavoritesRemote,
        defaults: UserDefaults = .standard,
        syncsAutomatically: Bool = true
    ) {
        self.context = context
        self.remote = remote
        self.defaults = defaults
        self.syncsAutomatically = syncsAutomatically
    }

    // MARK: - Local changes

    /// Persist a new favorite locally and queue it for upload. Throws only
    /// when the local save fails — the upload itself is retried as needed.
    func saveNew(_ workout: Workout) throws {
        let entity = WorkoutEntity(from: workout, updatedAt: .now, needsUpload: true)
        context.insert(entity)
        do {
            try context.save()
        } catch {
            context.delete(entity)
            throw error
        }
        requestSync()
    }

    /// Call after an edit was stamped with `markEdited()` and saved.
    func didEdit() {
        requestSync()
    }

    /// Delete a favorite locally and queue the remote delete. The local
    /// delete is authoritative: no rollback if the network is down, the
    /// tombstone makes the next pass finish the job.
    func delete(_ entity: WorkoutEntity) throws {
        let id = entity.id
        context.delete(entity)
        try context.save()
        var pending = pendingDeletionIDs
        pending.insert(id)
        pendingDeletionIDs = pending
        requestSync()
    }

    /// Drop queued deletes — on sign-out / account deletion, together with
    /// the local favorites wipe, so they don't leak into the next account.
    static func clearQueue(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingDeletionsKey)
    }

    // MARK: - Sync

    /// Fire-and-forget sync pass.
    func requestSync() {
        guard syncsAutomatically else { return }
        Task { await sync() }
    }

    /// Run a sync pass. Calls that arrive while a pass is running are
    /// coalesced into one follow-up pass, so passes never interleave.
    func sync() async {
        if isSyncing {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherPass = false
            await runPass()
        } while needsAnotherPass
    }

    private func runPass() async {
        do {
            try await pushPendingDeletions()
            let remoteRows = try await remote.fetchWorkouts()
            try reconcile(with: remoteRows)
            try await pushPendingUploads()
        } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
            // Guest mode or unconfigured backend — changes stay queued
            // and are pushed once the user signs in.
        } catch {
            log.warning("Favorites sync failed, will retry: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pushPendingDeletions() async throws {
        for id in pendingDeletionIDs {
            try await remote.deleteWorkout(id: id)
            var pending = pendingDeletionIDs
            pending.remove(id)
            pendingDeletionIDs = pending
        }
    }

    /// Merge the server's favorites into the local store. Internal so tests
    /// can drive it directly.
    func reconcile(with remoteRows: [RemoteWorkout]) throws {
        let deletedHere = pendingDeletionIDs
        let locals = try context.fetch(FetchDescriptor<WorkoutEntity>())
        let localByID = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var remoteIDs = Set<UUID>()

        for row in remoteRows {
            let id = row.workout.id
            remoteIDs.insert(id)
            // Deleted on this device, delete not pushed yet.
            if deletedHere.contains(id) { continue }
            if let local = localByID[id] {
                // Unpushed local edit that's newer than the server copy —
                // keep it; it's uploaded at the end of this pass.
                if local.needsUpload, local.updatedAt >= row.updatedAt { continue }
                local.apply(row.workout)
                local.updatedAt = row.updatedAt
                local.needsUpload = false
            } else {
                context.insert(WorkoutEntity(from: row.workout, updatedAt: row.updatedAt, needsUpload: false))
            }
        }

        // Synced before (nothing pending) but missing remotely: another
        // device deleted it. Local-only favorites are still pending and stay.
        for local in locals where !local.needsUpload && !remoteIDs.contains(local.id) {
            context.delete(local)
        }

        try context.save()
    }

    private func pushPendingUploads() async throws {
        let descriptor = FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.needsUpload == true })
        // Snapshot values first: the entity may be edited or deleted while
        // an upload is suspended.
        let pending = try context.fetch(descriptor).map { (id: $0.id, workout: $0.toWorkout(), editedAt: $0.updatedAt) }
        for item in pending {
            try await remote.upsertWorkout(item.workout)
            let id = item.id
            let current = try context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.id == id })).first
            // Edited again mid-upload → leave it queued for the follow-up pass.
            if let current, current.updatedAt == item.editedAt {
                current.needsUpload = false
                try context.save()
            }
        }
    }

    private var pendingDeletionIDs: Set<UUID> {
        get {
            let strings = defaults.stringArray(forKey: Self.pendingDeletionsKey) ?? []
            return Set(strings.compactMap(UUID.init(uuidString:)))
        }
        set {
            defaults.set(newValue.map(\.uuidString), forKey: Self.pendingDeletionsKey)
        }
    }
}

#if DEBUG
/// Shared in-memory store for SwiftUI previews, so views that need
/// `FavoritesSync` see the same context as their `@Query`.
@MainActor
enum PreviewStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: WorkoutEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
    static let favoritesSync = FavoritesSync(context: container.mainContext, remote: SupabaseManager.shared)
}
#endif
