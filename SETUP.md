# Interval — setup

## 1. Generate the Xcode project

```bash
xcodegen generate
open "Interval v1.xcodeproj"
```

Run `xcodegen generate` again any time you add/remove files or change
`project.yml`.

## 2. Configure Supabase

1. Create a project at https://supabase.com
2. Go to **Authentication → Providers** and enable **Apple**. Add the Apple
   service ID, team ID, key ID, and private key — see
   https://supabase.com/docs/guides/auth/social-login/auth-apple
3. Open **SQL Editor → New query** and paste the contents of
   [`Interval v1/Supabase/schema.sql`](Interval%20v1/Supabase/schema.sql).
   Run it to create the `workouts` and `user_preferences` tables with RLS.
4. Go to **Project Settings → API**, copy:
   - Project URL → `SupabaseConfig.url`
   - `anon` public key → `SupabaseConfig.anonKey`
5. Edit [`Interval v1/Supabase/SupabaseConfig.swift`](Interval%20v1/Supabase/SupabaseConfig.swift)
   and replace the placeholders.
6. (Recommended) Stop tracking the config file so your keys don't get
   committed:
   ```bash
   git rm --cached "Interval v1/Supabase/SupabaseConfig.swift"
   echo 'Interval v1/Supabase/SupabaseConfig.swift' >> .gitignore
   ```

The anon key is safe to ship inside the app binary — security is enforced by
Row Level Security policies (defined in `schema.sql`). Never embed the
`service_role` key.

## 3. Bundle the ambient audio files

See [`Interval v1/Resources/Audio/README.md`](Interval%20v1/Resources/Audio/README.md)
for the seven required files, format, and licensing notes. The app runs fine
without them — unavailable sounds are skipped at runtime.

## 4. Localization

Strings live in [`Interval v1/Localizable.xcstrings`](Interval%20v1/Localizable.xcstrings).
Open the file in Xcode to add English translations alongside the Dutch
source. The build extracts new strings automatically because
`SWIFT_EMIT_LOC_STRINGS` is enabled in `project.yml`.

## 5. Build & run

Select the **Interval v1** scheme and run on an iPhone simulator (or device).
Sign in with Apple works in the simulator; the Supabase bridge silently
no-ops if the config is still placeholder.

## v1 scope summary

In v1:
- Sign in with Apple (skippable)
- Set work/rest/rounds, start timer
- Background audio + signal tones + haptics
- Favorites persisted locally (SwiftData) + synced to Supabase when signed in
- Dutch UI, English translation infrastructure ready

Not in v1: workout history, templates, coach→patient sharing, Apple Watch,
push notifications, payments.
