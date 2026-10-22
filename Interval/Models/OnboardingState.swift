import Foundation
import Observation

/// Whether the welcome flow has been shown. Persisted under the same
/// `hasSeenOnboarding` key as before, so existing users don't see it again.
@MainActor
@Observable
final class OnboardingState {
    /// `@AppStorage` cannot live inside an `@Observable` class — it doesn't
    /// trigger observation. A plain `var` with `didSet` writing through to
    /// `UserDefaults` keeps both working.
    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: Self.key) }
    }

    @ObservationIgnored private static let key = "hasSeenOnboarding"

    init() {
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: Self.key)
    }

    func finish() {
        hasSeenOnboarding = true
    }
}
