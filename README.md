# Interval

Simpele, betrouwbare interval-timer voor iOS (work/rest/rounds) met stem-cues,
haptics, favorieten en optionele sync via Sign in with Apple + Supabase.

## Project opzetten (verse clone)

1. **Vereisten:** Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
   (`brew install xcodegen`).

2. **Supabase-config aanmaken** — dit bestand is bewust gitignored, zonder
   bouwt het project niet:

   ```bash
   cp SupabaseConfig.example.swift "Interval/Supabase/SupabaseConfig.swift"
   ```

   Vul daarna je project-URL en publishable key in
   (Supabase → Project Settings → API). Placeholders laten staan kan ook:
   de app draait dan volledig lokaal, zonder login/sync.

3. **Project genereren en openen:**

   ```bash
   xcodegen generate
   open "Interval.xcodeproj"
   ```

   `project.pbxproj` wordt gegenereerd uit `project.yml` — nieuwe bestanden
   toevoegen = opnieuw `xcodegen generate` draaien.

4. **Tests:** Cmd+U, of:

   ```bash
   xcodebuild test -project "Interval.xcodeproj" -scheme "Interval" \
     -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

## Backend (Supabase)

Migraties staan in `supabase/migrations/`. Deployen:

```bash
SUPABASE_DB_PASSWORD='<database-wachtwoord>' supabase db push
```

Let op: gratis Supabase-projecten pauzeren na ~1 week inactiviteit
(dashboard → Restore project).

## Docs

Zie `docs/` — o.a. `HANDOVER.md` (architectuur), `AUDIO_ARCHITECTURE.md`
(cue-systeem) en `IAP_AND_TESTFLIGHT.md` (voor wanneer de slapende
Pro-unlock ooit geactiveerd wordt; de app shipt nu volledig gratis via
`StoreManager.freeForEveryone`).
