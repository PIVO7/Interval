import Foundation
import Supabase
import AuthenticationServices
import os

/// Singleton wrapper around the Supabase client.
///
/// Responsibilities:
/// - Holds the configured `SupabaseClient`
/// - Bridges Sign in with Apple credentials into Supabase Auth
/// - Provides CRUD for `workouts` and `user_preferences` rows
///
/// Networking model: best-effort. SwiftData is the source of truth on device.
/// Every mutation writes locally first, then attempts a remote sync. Failures
/// are logged but do not block the UI. On next sign-in the local store is
/// reconciled with the remote.
@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "Supabase")

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    // MARK: - Auth

    /// Sign in to Supabase using an Apple Sign In credential.
    /// Returns the Supabase user id (uuid) on success.
    @discardableResult
    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws -> UUID {
        guard SupabaseConfig.isConfigured else {
            throw SupabaseError.notConfigured
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw SupabaseError.missingIdentityToken
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        return session.user.id
    }

    func signOut() async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            try await client.auth.signOut()
        } catch {
            log.warning("signOut failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Permanently delete the current user's account and all their server-side
    /// data (App Store Review Guideline 5.1.1(v)). Invokes the SECURITY DEFINER
    /// `delete_user` function — deleting `auth.users` requires privileges the
    /// client doesn't have directly. Signs out locally afterwards since the
    /// session is now invalid.
    func deleteAccount() async throws {
        guard SupabaseConfig.isConfigured else {
            throw SupabaseError.notConfigured
        }
        // Ensure the request carries a valid (refreshed) access token. The
        // delete_user() function relies on auth.uid() from the JWT — with a
        // stale/expired session that's null and the delete fails with "Not
        // authenticated". `client.auth.session` refreshes when needed (and
        // throws if there's genuinely no session, i.e. not signed in).
        _ = try await client.auth.session
        try await client.rpc("delete_user").execute()
        try? await client.auth.signOut()
    }

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Workouts

    /// Upsert a workout for the current user.
    func upsertWorkout(_ workout: Workout) async throws {
        guard SupabaseConfig.isConfigured, let userId = currentUserId else {
            throw SupabaseError.notSignedIn
        }
        let row = WorkoutRow(
            id: workout.id,
            userId: userId,
            name: workout.name,
            workSeconds: workout.workSeconds,
            restSeconds: workout.restSeconds,
            rounds: workout.rounds,
            createdAt: workout.createdAt
        )
        try await client.from("workouts").upsert(row).execute()
    }

    func deleteWorkout(id: UUID) async throws {
        guard SupabaseConfig.isConfigured, currentUserId != nil else {
            throw SupabaseError.notSignedIn
        }
        try await client.from("workouts").delete().eq("id", value: id).execute()
    }

    /// Fetch all workouts for the current user. Used on sign-in to seed local store.
    func fetchWorkouts() async throws -> [Workout] {
        guard SupabaseConfig.isConfigured, let userId = currentUserId else {
            throw SupabaseError.notSignedIn
        }
        let rows: [WorkoutRow] = try await client
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toWorkout() }
    }

    // MARK: - User preferences

    func upsertPreferences(_ prefs: UserPreferencesRow) async throws {
        guard SupabaseConfig.isConfigured, currentUserId != nil else {
            throw SupabaseError.notSignedIn
        }
        try await client.from("user_preferences").upsert(prefs).execute()
    }

    func fetchPreferences() async throws -> UserPreferencesRow? {
        guard SupabaseConfig.isConfigured, let userId = currentUserId else {
            throw SupabaseError.notSignedIn
        }
        let rows: [UserPreferencesRow] = try await client
            .from("user_preferences")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notConfigured
    case notSignedIn
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is niet geconfigureerd. Vul SupabaseConfig.swift in."
        case .notSignedIn:
            return "Niet ingelogd bij Supabase."
        case .missingIdentityToken:
            return "Apple identity token ontbreekt."
        }
    }
}

// MARK: - Row DTOs
//
// Supabase columns are snake_case; Swift convention is camelCase. We keep
// Swift naming and bridge via `CodingKeys` rather than carrying snake_case
// through the rest of the codebase.

private struct WorkoutRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let workSeconds: Int
    let restSeconds: Int
    let rounds: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, rounds
        case userId = "user_id"
        case workSeconds = "work_seconds"
        case restSeconds = "rest_seconds"
        case createdAt = "created_at"
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
}

struct UserPreferencesRow: Codable {
    let userId: UUID
    var defaultSound: String
    var soundVolume: Double
    var signalTonesEnabled: Bool
    var hapticsEnabled: Bool
    var languageOverride: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultSound = "default_sound"
        case soundVolume = "sound_volume"
        case signalTonesEnabled = "signal_tones_enabled"
        case hapticsEnabled = "haptics_enabled"
        case languageOverride = "language_override"
    }
}
