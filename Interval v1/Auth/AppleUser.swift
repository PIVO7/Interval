import Foundation

/// Persisted representation of an Apple Sign In credential. Lives in
/// `UserDefaults` (no sensitive data — Apple identity tokens are short-lived
/// and re-fetched on each sign-in). `supabaseUserId` is filled in once the
/// Apple credential is exchanged for a Supabase Auth session.
struct AppleUser: Codable {
    let userId: String
    var fullName: String?
    var email: String?
    var supabaseUserId: UUID?
}
