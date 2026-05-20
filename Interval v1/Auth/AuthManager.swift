import Foundation
import AuthenticationServices
import SwiftUI
import Observation
import os

struct AppleUser: Codable {
    let userId: String
    var fullName: String?
    var email: String?
    var supabaseUserId: UUID?
}

@MainActor
@Observable
final class AuthManager {
    var user: AppleUser?
    var isLoading: Bool = false
    var errorMessage: String?

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

            // Bridge into Supabase Auth — best effort. Local sign-in succeeds either way.
            // The Task inherits @MainActor from the enclosing class, so no
            // MainActor.run hop is needed.
            Task { [weak self] in
                do {
                    let supabaseId = try await SupabaseManager.shared.signInWithApple(cred)
                    newUser.supabaseUserId = supabaseId
                    self?.user = newUser
                    self?.persist(newUser)
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
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        user = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        Task { await SupabaseManager.shared.signOut() }
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
