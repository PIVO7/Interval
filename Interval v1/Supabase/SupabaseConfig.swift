import Foundation

/// Supabase project credentials.
///
/// To configure:
/// 1. Create a project at https://supabase.com
/// 2. Go to Project Settings → API
/// 3. Replace the placeholders below with your project URL and `anon` public key
/// 4. (Recommended) Move this file out of source control:
///    `git rm --cached "Interval v1/Supabase/SupabaseConfig.swift"`
///    and add `Interval v1/Supabase/SupabaseConfig.swift` to .gitignore
///
/// The anon key is safe to ship in clients — it relies on Row Level Security (RLS)
/// configured in Supabase. See `Supabase/schema.sql` for the required policies.
enum SupabaseConfig {
    static let url = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR-ANON-PUBLIC-KEY"

    static var isConfigured: Bool {
        !anonKey.hasPrefix("YOUR-") && !url.absoluteString.contains("YOUR-PROJECT-REF")
    }
}
