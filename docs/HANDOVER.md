# Interval app — handover na sessie 21–22 mei 2026

## Project context

iOS-app `com.superapp.intervalv1` voor coaches/kinesitherapeuten:
intervaltimer met work/rest/rounds, achtergrondgeluid, Live Activity,
Sign in with Apple → Supabase voor cross-device favorites.

**Project root**: `/Users/jellewauters/Superapp-Projects/Interval v1/`
**Versie**: 1.0 build 4 in TestFlight (build 5 nodig om push fix te
testen). Werkmap is XcodeGen-gebaseerd, run `xcodegen generate` na
project.yml-wijziging.

**Identifiers:**
- Apple Team ID: `VB6FS3N78T`
- App ID: `com.superapp.intervalv1`
- Services ID (Sign in with Apple via Supabase): `com.superapp.intervalv1.signin`
- Widget bundle: `com.superapp.intervalv1.widget`
- APNs Auth Key ID: `76C427WRHC` (.p8 in ~/Downloads/)
- Supabase project ref: `gfescsrjilmprsyuzipj`
- Supabase URL: `https://gfescsrjilmprsyuzipj.supabase.co`
- Contact email: jelle@pivo7.be

---

## ✅ Voltooid

### Live Activity – lokale kant
- TimerEngine wall-clock-based (was decrement-based)
- `recomputeFromWallClock` op scenePhase `.active`
- LiveActivityManager: `staleDate=nil`, `relevanceScore=100`
- Pause/skip shift `phaseStartedAt`/`phaseEndsAt` mee
- Race-fix via `pendingState` reconciliation
- Widget gebruikt `phaseStartDate...phaseEndDate` consistent in Text + ProgressView
- `IntervalActivityAttributes: Sendable`
- `finish()`/`endImmediately()` nullen activity property vóór async dismissal
- LockScreenView trophy state gecentreerd
- Dynamic Island + LockScreen views in widget target

### Live Activity – push pipeline (gedeployed, NOG NIET WERKEND – zie pending)
- `aps-environment = development` entitlement
- Activity.request gebruikt `pushType: .token`
- `Activity.pushTokenUpdates` AsyncSequence geobserveerd
- LiveActivityPushScheduler.swift + ScheduledLiveActivityPush.swift in `Interval v1/LiveActivity/`
- Supabase migration `20260521120000_live_activity_pushes.sql` + `20260521130000_dispatcher_hardcoded_url.sql`
- Edge Functions live: `schedule-live-activity`, `cancel-live-activity`, `send-due-live-activity-pushes`
- pg_cron job draait elke minuut, inner-loop voor 1s precisie via pg_sleep
- APNs JWT signing met jose lib in Deno
- Secrets in Supabase: APNS_TEAM_ID, APNS_KEY_ID, APNS_AUTH_KEY
- `send-due-live-activity-pushes` heeft `verify_jwt = false`

### App modernization (allemaal in git)
- @Observable migratie: WorkoutStore, AudioSettings, AuthManager
- IntervalApp `@State` + `.environment(...)` voor injectie
- Modern Tab API, onChange two-param, Duration FormatStyle
- @ScaledMetric voor ring + timer text
- visualEffect voor blob offsets (was GeometryReader)
- Logger overal (was NSLog)
- Task.sleep (was DispatchQueue.main.asyncAfter)
- .sensoryFeedback (was UINotificationFeedbackGenerator)
- nonisolated(unsafe) op TimerEngine.tickTask voor Swift 6

### Apple Developer + Supabase setup
- Sign in with Apple capability + Services ID + .p8 key
- APNs Auth Key (Push Notifications) en capability op App ID **wel** aangevinkt
- Supabase Apple auth provider wired (JWT generated via Python script)
- Supabase schema voor workouts, user_preferences

### App features / UI
- App icon: nieuwe stopwatch (coral bg + white symbol), gecentreerd in canvas (37px omhoog shift)
- Round indicator: title3/heavy + visual progress dots (≤12) / bar (>12)
- Active timer: 320pt ring, 96pt heavy font, Dynamic Type scaling
- Favorites: alleen play-knop start, slider-icon opent in-place EditFavoriteSheet (sheet)
- Universal iPhone+iPad, iPad landscape support
- Onboarding: SignInWithAppleButton primary + "Verder zonder account" secondary
- AccountView: signed-in/out variants, "Sync je trainingen" copy
- Appearance toggle System/Light/Dark in AccountView
- Privacy Policy in `docs/PRIVACY.md` (Nederlands, GDPR-compliant)
- PrivacyInfo.xcprivacy in main app + widget extension

### Bug fixes
- "Synchroniseren mislukt" alert silenced voor guest mode (catch SupabaseError.notSignedIn)
- Sign in with Apple werkt (na provisioning profile refresh)
- Errors uit Supabase upsertWorkout surfaced via alerts (niet langer try?)

---

## 🟡 Open issues / pending

### 🔴 KRITIEK: Live Activity push pipeline werkt nog niet

**Symptoom**: Live Activity verschijnt wel bij workout-start, maar stopt
na werkblok 1 (eerste test) of na rest 1 (volgende test, scenario
verschilde). **Push notifications komen NIET aan** op vergrendelde iPhone.

**Wat is gecheckt**:
- ✅ Build 4 met push-code geïnstalleerd via TestFlight
- ✅ Live Activity zelf verschijnt → `Activity.request(pushType: .token)` slaagt
- ✅ Push Notifications capability AAN op App ID `com.superapp.intervalv1` in developer portal
- ❌ `live_activity_pushes` tabel in Supabase blijft **leeg** — iPhone POST nooit een schedule
- ❌ `schedule-live-activity` Edge Function heeft **0 invocations**

**Conclusie**: token wordt niet geëmit door `activity.pushTokenUpdates` OF
de POST faalt silently. iOS-kant probleem, NIET Supabase-kant.

**Meest waarschijnlijk**: stale provisioning profile. We hebben Push
Notifications capability AANGEZET nadat het project al eerder
gearchiveerd is. Xcode auto-regenereert profile bij archive maar
doet dat soms niet.

**Volgende stappen die nog niet zijn uitgevoerd**:
1. Xcode → target Interval v1 → Signing & Capabilities → toggle
   "Automatically manage signing" OFF en weer ON
2. Clean Build Folder ⌘⇧K
3. Bump `CURRENT_PROJECT_VERSION` 4 → 5 in project.yml
4. xcodegen generate
5. Archive opnieuw als build 5
6. Distribute → App Store Connect → Upload
7. TestFlight install op iPhone
8. Test workout → check Supabase tabel of rijen verschijnen

**Als dat niet helpt** — diagnose via Console.app:
- iPhone via kabel naar Mac
- Console.app open, iPhone selecteren, filter `subsystem:com.superapp.intervalv1`
- Start workout
- Zoek naar log lines van `LiveActivity` category:
  - "Scheduled N Live Activity pushes" = OK
  - "schedule-live-activity failed: ..." = POST faalt
  - (niets) = token komt niet via pushTokenUpdates

### 🟡 Audio: marimba-versie uncommitted

Werk-tree heeft een marimba-style synth (warmer dan eerdere boxing-bell
en pure-pulse experimenten). User had feedback:
"te houterig, te scherp, te kort" → ik heb 4× partial verlaagd naar 0.28,
9.7× partial naar 0.03, decay constant naar 4.0, durations verlengd.
**User heeft deze laatste iteratie nog niet getest**. Niet committed.

File: `Interval v1/Audio/AudioEngine.swift` (uncommitted in working tree)

### 🟡 TestFlight Beta App Review

In progress — user is bezig met "Test Information" invullen.
- Build 4 in External Testing group "Friends and family"
- Privacy Policy URL nog niet ingevuld (GitHub Pages setup in
  progress, repo nog leeg)
- Submit for Review nog niet gebeurd

### 🟡 Live Activity stopt na eerste rest (laatste test)

In de allerlaatste test rapporteerde user dat de symptoom veranderd is
naar "stopt na eerste rest". Verschilt van eerdere "stopt na eerste
blok". Mogelijk dat user nu met ambient sound aan tested → app blijft
alive door audio mode → krijgt 1 extra transition (work → rest) maar
sneuvelt daarna. Diagnostic questions waren in flight maar tool
permission error blokkeerde antwoord.

### 🟢 Niet-blockers maar wel TODO

- **WorkoutKit Apple Watch export**: code in `Interval v1/WorkoutKit/WorkoutKitExporter.swift` is geschreven en compileert maar **niet gewired in UI**. Zou een "Stuur naar Watch" knop op Home of Favorites kunnen.
- **Subscriptions / paywall**: user wil Pro-versie maar bewust gedeferd tot na TestFlight feedback. Plan B in eerdere reviews: Pattern C (free guest + sign-in required for purchase).
- **Tests**: er is een Interval v1 Tests target met enkele TimerEngineTests, WorkoutTests etc. maar nieuwe @Observable + push code is niet test-covered.
- **Localization**: `Localizable.xcstrings` heeft Nederlandse source strings; geen Engelse vertalingen. Project is iPad/iPhone NL-first dus mag wachten.
- **Image asset for App Store**: marketing 1024×1024 staat in `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Voor App Store screenshots (≠ TestFlight) zijn ook nog ~5 screenshots per device size nodig — niet nodig voor pure TestFlight.

---

## Belangrijke files

```
Interval v1/
├── project.yml                                          # XcodeGen config — bevat CURRENT_PROJECT_VERSION
├── Icon/
│   ├── AppIcon.svg                                       # composited 1024 source
│   ├── IntervalIcon_Background.svg                       # cream/coral gradient layer
│   └── IntervalIcon_Foreground.svg                       # white stopwatch layer
├── Interval v1/
│   ├── Interval v1.entitlements                          # applesignin + aps-environment
│   ├── Info.plist                                        # NSSupportsLiveActivities, UISupportedInterfaceOrientations
│   ├── PrivacyInfo.xcprivacy
│   ├── Audio/AudioEngine.swift                           # ⚠️ uncommitted marimba experiment
│   ├── Audio/AudioSettings.swift                         # @Observable
│   ├── Auth/AuthManager.swift                            # @Observable, AppStorage→didSet pattern
│   ├── LiveActivity/
│   │   ├── LiveActivityManager.swift                     # ActivityKit wrapper, pushType .token
│   │   ├── LiveActivityPushScheduler.swift               # POSTs schedule to Supabase
│   │   └── ScheduledLiveActivityPush.swift               # Workout.liveActivitySchedule(...)
│   ├── Models/{Workout, WorkoutStore, WorkoutEntity}.swift
│   ├── Navigation/RootTabView.swift                      # modern Tab API
│   ├── Screens/Active/{TimerEngine, ActiveTrainingView, CountdownView, FinishedView}.swift
│   ├── Screens/Account/AccountView.swift
│   ├── Screens/Favorites/{FavoritesView, EditFavoriteSheet}.swift
│   ├── Screens/Home/{HomeView, InlineTimeWheel, InlineRoundsWheel, ValuePickerRow, SaveFavoriteSheet}.swift
│   ├── Screens/Onboarding/OnboardingView.swift
│   ├── Supabase/{SupabaseManager, SupabaseConfig, schema.sql}
│   └── Theme/{AppTheme, Animations, AppearanceMode, AppearanceSettings}.swift
├── Interval Widget/
│   ├── Info.plist + PrivacyInfo.xcprivacy
│   ├── IntervalWidgetBundle.swift
│   ├── IntervalLiveActivity.swift                        # Dynamic Island + ActivityConfiguration
│   ├── LockScreenView.swift
│   ├── ActivityPhase+UI.swift                            # tints, gradients, labels
│   └── WidgetBrand.swift                                 # brand colors duplicated
├── Shared/
│   ├── ActivityPhase.swift
│   └── IntervalActivityAttributes.swift                  # Sendable
├── supabase/
│   ├── config.toml                                       # verify_jwt = false op send-due-*
│   ├── README.md                                         # volledige deploy instructies
│   ├── migrations/
│   │   ├── 20260521120000_live_activity_pushes.sql       # ⚠️ originele met current_setting (al gedeployed maar werkt niet — vervangen door volgende)
│   │   └── 20260521130000_dispatcher_hardcoded_url.sql   # fix: hardcoded URL, no auth header
│   └── functions/
│       ├── schedule-live-activity/index.ts
│       ├── cancel-live-activity/index.ts
│       └── send-due-live-activity-pushes/index.ts
└── docs/
    ├── PRIVACY.md                                        # NL GDPR-compliant policy
    └── HANDOVER.md                                       # dit bestand
```

## Commit historie (laatste eerst)

```
5629a34 Center stopwatch icon — shift artwork up 37px
7c3dfe3 Live Activity review fixes + polish (icon, sounds, round indicator)
7efc163 Apple Watch-style audio + bump build to 3
1d94500 Favorites edit sheet, new stopwatch icon, 9 swiftui-pro polish items
663636f Larger, bolder timer in ActiveTrainingView
acffc94 Make app universal (iPhone + iPad)
1b533ff Enable landscape on iPad
c04faca Fix: silence Supabase sync alert for guest users + bump build to 2
c44e863 Light/Dark/System appearance toggle + AccountView polish
c538dcd Sign in with Apple UI, privacy manifest, app icon
7bd8106 Live Activity, WorkoutKit export, Home redesign, modern @Observable
```

**Niet committed**: Audio marimba iteratie + Supabase code (de hele
`supabase/` map is nog niet in een commit — alleen functioneel
gedeployed naar Supabase cloud). Zie `git status` voor de exacte
dirty state.

## Eerste opdracht voor nieuwe sessie

Suggestie voor je nieuwe sessie's openings-prompt:

> "Lees `docs/HANDOVER.md` en `docs/PRIVACY.md`. De kritieke open issue
> is dat Live Activity push notifications niet aankomen op de
> vergrendelde iPhone. Probeer met mij door de gesuggereerde fix te
> lopen: provisioning profile refresh in Xcode, build 5 archiveren,
> testen. Daarna Console.app diagnose als het nog niet werkt."
