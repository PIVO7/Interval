import Foundation
import AuthenticationServices
import SwiftUI

struct AppleUser: Codable {
    let userId: String
    var fullName: String?
    var email: String?
    var supabaseUserId: UUID?
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var user: AppleUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false

    private let userKey = "interval_apple_user"

    init() {
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
            Task { [weak self] in
                do {
                    let supabaseId = try await SupabaseManager.shared.signInWithApple(cred)
                    newUser.supabaseUserId = supabaseId
                    await MainActor.run {
                        self?.user = newUser
                        self?.persist(newUser)
                    }
                } catch SupabaseError.notConfigured {
                    NSLog("[AuthManager] Supabase not configured — skipping cloud sign-in")
                } catch {
                    NSLog("[AuthManager] Supabase sign-in failed: %@", error.localizedDescription)
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
