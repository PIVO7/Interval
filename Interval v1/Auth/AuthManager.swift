import Foundation
import AuthenticationServices
import SwiftUI
import SwiftData
import Observation
import os

@MainActor
@Observable
final class AuthManager {
    var user: AppleUser?
    var isLoading: Bool = false
    /// Latest auth error message (nil when no error pending). Use
    /// `errorVersion` to detect new errors — `.onChange(of: errorMessage)`
    /// misses an identical message thrown twice in succession.
    var errorMessage: String?
    /// Monotonic counter bumped on every `errorMessage` assignment (even
    /// when the new string equals the old). Views observe this to know
    /// "there's a new error to show" without relying on string equality.
    private(set) var errorVersion: Int = 0

    /// `@AppStorage` cannot live inside an `@Observable` class — it doesn't
    /// trigger observation. Use a plain `var` with `didSet` writing through
    /// to `UserDefaults` instead. View updates fire via the observation macro,
    /// persistence runs as a side-effect.
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.onboardingKey) }
    }

    @ObservationIgnored private let log = Logger(subsystem: "com.superapp.intervalv1", category: "Auth")
    @ObservationIgnored private let userKey = "interval_apple_user"
    @ObservationIgnored private static let onboardingKey = "hasSeenOnboarding"
    /// Identifies the in-flight Apple→Supabase bridge so a sign-out (or a
    /// second sign-in) between authorization and Supabase resolution can
    /// invalidate the now-stale write-back.
    @ObservationIgnored private var inFlightAuthorizationId: UUID?

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        loadPersistedUser()
    }

    var isSignedIn: Bool { user != nil }

    // MARK: - Sign in with Apple
    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        isLoading = false
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let name: String? = {
                guard let given = cred.fullName?.givenName else { return nil }
                let family = cred.fullName?.familyName ?? ""
                return "\(given) \(family)".trimmingCharacters(in: .whitespaces)
            }()
            var newUser = AppleUser(
                userId: cred.user,
                fullName: name?.isEmpty == false ? name : persistedUser()?.fullName,
                email: cred.email ?? persistedUser()?.email,
                supabaseUserId: persistedUser()?.supabaseUserId
            )
            user = newUser
            persist(newUser)
            hasSeenOnboarding = true

            // Tag this authorization so the async Supabase bridge can
            // detect a sign-out / re-sign-in that happened mid-flight and
            // skip writing back a stale supabaseUserId.
            let authorizationId = UUID()
            inFlightAuthorizationId = authorizationId
            let signedInUserId = cred.user

            Task { [weak self] in
                do {
                    let supabaseId = try await SupabaseManager.shared.signInWithApple(cred)
                    guard let self else { return }
                    // Reject the write if (a) the user signed out, (b) a
                    // newer authorization superseded this one, or (c) the
                    // current user is for a different Apple account.
                    guard self.inFlightAuthorizationId == authorizationId,
                          self.user?.userId == signedInUserId else {
                        self.log.notice("Discarded supabase sign-in result — superseded by signOut/re-sign-in")
                        return
                    }
                    newUser.supabaseUserId = supabaseId
                    self.user = newUser
                    self.persist(newUser)
                } catch SupabaseError.notConfigured {
                    self?.log.info("Supabase not configured — skipping cloud sign-in")
                } catch {
                    self?.log.error("Supabase sign-in failed: \(error.localizedDescription, privacy: .public)")
                }
            }

        case .failure(let error):
            // ASAuthorizationError.canceled (1001) — user tapped cancel, no message needed
            let nsErr = error as NSError
            if nsErr.code != ASAuthorizationError.canceled.rawValue {
                reportError(error.localizedDescription)
            }
        }
    }

    /// Single funnel for setting `errorMessage` so `errorVersion` always
    /// stays in lockstep. Call this instead of writing `errorMessage`
    /// directly anywhere a new error needs to surface to the UI.
    func reportError(_ message: String) {
        errorMessage = message
        errorVersion &+= 1
    }

    /// Clear a surfaced error after the user dismisses it. Paired with
    /// `reportError` so views don't poke `errorMessage` directly.
    func clearError() {
        errorMessage = nil
    }

    /// Sign out and clear all per-user device state.
    ///
    /// `modelContext` is passed in so caller can wipe SwiftData favorites
    /// on the same actor. Without this, a second user on the same device
    /// inherits the previous user's locally-stored workouts and would
    /// upsert them as their own on the next save.
    func signOut(modelContext: ModelContext? = nil) {
        // Invalidate any in-flight Apple→Supabase bridge so it can't
        // resurrect `user` after we've cleared it.
        inFlightAuthorizationId = nil
        user = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        // Force onboarding to re-show so the next signer-in (or guest)
        // gets the welcome flow rather than landing straight on Home with
        // the previous account's UI state.
        hasSeenOnboarding = false

        if let modelContext {
            do {
                try modelContext.delete(model: WorkoutEntity.self)
                try modelContext.save()
            } catch {
                log.error("Failed to wipe local workouts on signOut: \(error.localizedDescription, privacy: .public)")
            }
        }

        Task { await SupabaseManager.shared.signOut() }
    }

    /// Permanently delete the user's account: server-side data + auth record
    /// first, then all local device state. Throws if the remote delete fails
    /// so the caller can surface an error and *not* pretend the account is
    /// gone — local state is only cleared once the server confirms.
    func deleteAccount(modelContext: ModelContext? = nil) async throws {
        try await SupabaseManager.shared.deleteAccount()

        // Remote delete succeeded — now wipe local state (mirrors signOut, but
        // the remote signOut already happened inside deleteAccount()).
        inFlightAuthorizationId = nil
        user = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        hasSeenOnboarding = false

        if let modelContext {
            do {
                try modelContext.delete(model: WorkoutEntity.self)
                try modelContext.save()
            } catch {
                log.error("Failed to wipe local workouts on deleteAccount: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func skipOnboarding() {
        hasSeenOnboarding = true
    }

    // MARK: - Persistence (no sensitive data — just display name + non-private email)
    private func persist(_ u: AppleUser) {
        if let data = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func persistedUser() -> AppleUser? {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let u = try? JSONDecoder().decode(AppleUser.self, from: data) else { return nil }
        return u
    }

    private func loadPersistedUser() {
        user = persistedUser()
    }
}
