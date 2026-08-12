// Template for the gitignored "Interval/Supabase/SupabaseConfig.swift".
//
// That file is deliberately NOT in source control (see .gitignore), so a
// fresh clone won't build until you create it:
//
//   1. Copy this file to:  Interval/Supabase/SupabaseConfig.swift
//   2. Fill in your project URL and publishable (anon) key from
//      Supabase → Project Settings → API
//
// The publishable key is safe to ship in clients — data access is enforced
// by Row Level Security on the server. Keeping the file out of git is
// defense-in-depth, not secrecy.

import Foundation

enum SupabaseConfig {
    static let url = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR-PUBLISHABLE-KEY"

    static var isConfigured: Bool {
        !anonKey.hasPrefix("YOUR-") && !url.absoluteString.contains("YOUR-PROJECT-REF")
    }
}
