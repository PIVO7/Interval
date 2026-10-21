# Release notes — volgende update (na build 6)

Lopende notitielijst van wijzigingen die opgenomen moeten worden in de
release-/TestFlight-notes en getest moeten worden vóór archive.

---

## Wijzigingen sinds vorige build

### Nieuwe feature: workout aanpassen tijdens pauze
- Tijdens een lopende workout kun je nu work/rest/rounds aanpassen,
  enkel terwijl gepauzeerd (in work- of rest-fase). Niet tijdens de
  3-2-1 countdown of na finished.
- Huidige fase blijft op de oorspronkelijke duur — wijzigingen
  treden in werking vanaf de eerstvolgende fase-transitie. Geen
  "lurch" van de actieve timer.
- Rounds kan nooit lager dan `currentRound` — clamping voorkomt
  impossible states. Lager zetten tot exact `currentRound` laat de
  workout finishen na deze ronde (geen trailing rest).
- Edits zijn ignored als de engine niet "canAdjust" is — UI hides
  de affordance dan ook.

### UI-flow voor de aanpassing
- "Workout aanpassen"-pill verschijnt alleen tijdens pauze, boven de
  Stop/Hervat/Skip-rij. Vliegt in van onder met opacity-fade
  (`snappy(0.32)`).
- Tap opent `AdjustWorkoutSheet`: vaste hoogte 520pt, drag-indicator
  verborgen — bewust niet resizable, want "quick-tune affordance,
  geen browsing surface". Accordion met dezelfde wheels als
  EditFavoriteSheet/HomeView voor consistentie.
- Sheet committed wijzigingen live; "Klaar"-knop dismist enkel.

### iPad-polish: FinishedView max-width
- Op iPad Pro stretchte de stats-card en de twee actieknoppen
  ("Opslaan als favoriet" / "Terug naar home") over de volledige
  schermbreedte → onhandige ~900pt brede capsule-buttons.
- Content nu gecapt op `maxWidth: 560` met centrering, identiek
  aan OnboardingView's pattern. iPhone-layout volledig ongewijzigd.

### Audio-architectuur herbouwd (zie `docs/AUDIO_ARCHITECTURE.md`)
- Monolithische `AudioEngine` vervangen door gelaagde architectuur:
  `CueOrchestrator` + `CueChannel`-protocol + `VoicePlayer`
  (`AVAudioEngine` + voorgeladen PCM-buffers) + `HapticPlayer`
  (`CHHapticEngine` + custom transients) + `AudioSessionController`.
- `TimerEngine` praat nog enkel met `CueOrchestrator` via een
  semantisch `WorkoutCue` enum (`countdownTick(secondsLeft:)`,
  `workStart`, `restStart`, `finished`). Geen `AVAudioPlayer`,
  `UIImpactFeedbackGenerator`, of synth-code meer in de engine.
- **Audio session lifecycle per-workout**: bij start
  `setCategory(.playback, options: [.duckOthers,
  .interruptSpokenAudioAndMixWithOthers])` → Spotify/Apple Music
  ducken naar ~50% tijdens cues. Bij stop/finished
  `setActive(false, options: .notifyOthersOnDeactivation)` →
  externe muziek terug naar 100%.
- **Latency-verbetering**: PCM-buffers blijven in memory tijdens
  de workout, scheduled via `AVAudioPlayerNode` (~5ms i.p.v. 20-50ms
  per cue door per-shot `AVAudioPlayer`-instantiatie).
- **Haptics**: Core Haptics `CHHapticPattern`s i.p.v.
  `UIImpactFeedbackGenerator`. Engine herstelt automatisch via
  `resetHandler` na audio-session interrupts. Finished-cue is een
  3-pulse cascade i.p.v. de oude generic `.success`-feedback.
- **Test-architectuur**: `MockCueOrchestrator` injectie vervangt
  de oude `isHeadlessForTesting`-flag. Tests verifiëren nu cue
  emission via `cues.emittedCues` zonder enige audio/haptics
  hardware nodig.
- **Voice clips gebundled**: 8 ElevenLabs-AI-stemclips
  (Engels) zitten in `Interval/Resources/Audio/`:
  `cue_three / two / one / work_start / rest_start / halfway /
  last_round / finished`. Synth-code volledig uit `VoicePlayer`
  verwijderd. AAC m4a 44.1 kHz stereo, ~94 KB elk, totaal ~750 KB
  bundle-impact. Licentie-archief vóór release: zie
  `docs/VOICE_CLIPS_GUIDE.md` (Starter $6, archiveren in
  `docs/voice_clips_license/`).
- **Voice clips taal-besluit**: bundled voice clips zijn
  **English-only** (zie `docs/VOICE_CLIPS_GUIDE.md`). Reden: Engels
  is universele fitness-vocabulary, professioneler op internationaal
  niveau, en ElevenLabs heeft een veel grotere voice library voor
  EN dan NL. VoiceOver-announcements (`WorkoutCue.spokenDescription`)
  blijven Nederlands via `Localizable.xcstrings` — dat is een
  aparte channel die op accessibility focust.

### Halfway + Last round cues
- `WorkoutCue.halfway` en `WorkoutCue.lastRound` toegevoegd —
  vervangen `.workStart` op specifieke rondes.
- **Last round**: vuurt op start van laatste ronde, alleen als
  `rounds >= 2` (niet voor 1-ronde workouts).
- **Halfway**: vuurt op start van ronde `⌊rounds/2⌋ + 1`, alleen
  als `rounds >= 4` (voor 3 rondes en minder voelt het te vroeg).
- Bij collisie wint `.lastRound` (informatiever dan halfway).
- HapticPlayer hergebruikt het `workStart`-pattern; later kan een
  designer custom AHAP toevoegen.

### "Herhaal" knop op FinishedView
- Nieuwe primaire actie op het summary-scherm: `Herhaal` met
  `arrow.clockwise` icoon. Direct terug naar de countdown met
  dezelfde workout-instellingen. Apple Fitness+ / Nike Training
  Club pattern voor HIIT-gebruikers die meerdere sets willen doen.
- Knoppen herrangschikt: Save (secondary capsule) → Herhaal
  (primary wit capsule) → Terug naar home (tertiary text-link).
- `TimerEngine.restart()` reset state zonder de audio session te
  cyclen — geen ducking-flicker tegen achtergrondmuziek.

### Bug fixes
- **Finished cue werd afgekapt**: `cues.workoutDidEnd()` werd direct
  na `cues.emit(.finished)` aangeroepen → audio engine stopte
  voordat de "Great work!" cue kon afspelen. Workout-end lifecycle
  gebeurt nu pas via `engine.stop()` op view-dismissal, zodat de
  cue volledig kan spelen.
- **NL-locale "totale tijd" wrap-bug**: `Duration.formatted(.units(...
  .narrow))` produceert in NL "1 m, 10 s" — de komma deed de text
  renderer wrappen naar 2 regels in de FinishedView stats card.
  Vervangen door nieuwe `Int.asCompactDuration` extension die
  "45s" / "1m 10s" / "1h 5m" produceert (geen komma's, één regel,
  consistent met `Workout.summary`-format).
- HomeView summary-card en FinishedView stats-card gebruiken nu
  beide het compacte format + `lineLimit(1)` + `minimumScaleFactor`
  als safety voor extreme waarden.
- HomeView summary-card: redundante summary-sublijn ("30s werk ·
  15s rust · 8 ronden") verwijderd — info staat al in de
  `IntervalsListView` daaronder, plus de middle-dots ogen rommelig.

### Review-fixes vóór release (sync, timer, store, sign-in)
- **Sync-wachtrij** (`FavoritesSync`): elke opslag/bewerking zet
  `needsUpload` op de favoriet, elke verwijdering een tombstone. Een
  mislukte upload/delete blijft in de wachtrij en wordt opnieuw
  geprobeerd bij launch, sign-in, terug naar de voorgrond en de
  volgende lokale wijziging. Geen rollback meer bij een offline delete.
- **Conflicten**: last-writer-wins op `updatedAt` (lokale bewerktijd
  vs. `updated_at` van de server). Een oudere servercopy overschrijft
  geen nieuwere offline-bewerking meer.
- **Verwijderingen synchroniseren**: favorieten die al gesynct waren
  maar niet meer op de server staan, worden lokaal verwijderd.
- **Migratie**: bestaande favorieten krijgen `needsUpload = true` +
  `updatedAt = distantPast` — ze worden geüpload tenzij de server al
  een copy heeft, en dus nooit als "elders verwijderd" weggegooid.
- **Timer-drift**: automatische fase-overgangen starten vanaf de
  geplande deadline i.p.v. het (late) tick-moment. Een lange stall
  spoelt stil door (één cue voor de fase waarin je landt).
- **Paywall**: laadt het product opnieuw bij openen als het bij launch
  mislukte; bij een fout toont de knop "Opnieuw proberen".
- **Sign-in**: lukt Apple wel maar de cloud-koppeling niet, dan krijg
  je een melding en toont Account "Synchronisatie niet verbonden" met
  een knop om opnieuw te verbinden.

---

## Tests-coverage toegevoegd

Nieuwe tests in `TimerEngineTests`:
- `canAdjust` gating (countdown / running / paused / finished)
- Updating work/rest/rounds tijdens pauze
- Future-phase-effect (huidige fase ongewijzigd, volgende fase nieuw)
- Rest=0 mid-workout skipt rest vanaf volgende ronde
- Rounds-clamping op `currentRound`
- Rounds lager → finish na huidige ronde, geen trailing rest
- WorkSeconds clamped op minimum (5)
- Adjustments genegeerd buiten pauze
- Cue emission (init / skip / final round / stop)
- `lastRound` op laatste ronde (rounds=2/3/4/8)
- `halfway` op midden-ronde (rounds=4/8)
- Geen `halfway` voor rounds=1/2/3 (te klein)
- `lastRound` wint bij halfway/lastRound collision
- `restart()` reset state (vanaf finished + mid-workout)
- `finished` cue fires zonder dat lifecycle direct sluit (bug fix
  test: `endCalls == 0` na finished, niet `>= 1`)

Build groen, ~30 tests in totaal.

---

## Te testen vóór release

- [ ] Aanpassen-pill verschijnt/verdwijnt netjes bij pauze/hervat
- [ ] Sheet opent op exacte hoogte op iPhone SE (kleinste device)
- [ ] Tijdens pauze: edit work → hervat → volgende work-fase
      gebruikt nieuwe waarde
- [ ] Rounds lager zetten dan huidige ronde clamps correct
- [ ] Rest naar 0 mid-workout → volgende ronde zonder rest
- [ ] FinishedView op iPad Pro 13": knoppen + stats card
      gecentreerd, niet stretched
- [ ] FinishedView op iPhone: layout identiek aan voorheen
- [ ] Workout start met Spotify aan → muziek duckt tijdens cues
- [ ] Workout stoppen/finishen → Spotify direct terug naar 100%
- [ ] Haptics voelen vergelijkbaar met voorheen (countdown, work,
      rest, finished celebration)
- [ ] Cues spelen op tijd zonder hoorbare latency bij 3-2-1-GO
- [ ] Voice clip "Three / Two / One / Go!" wordt gehoord aan
      countdown-einde
- [ ] Voice clip "Rest" wordt gehoord bij rest-fase
- [ ] Voice clip "Halfway" wordt gehoord bij ronde 5 van 8 (test
      met een 8-ronden workout)
- [ ] Voice clip "Last round!" wordt gehoord bij laatste ronde
      (test met 4 of 8 rondes)
- [ ] Voice clip "Great work!" wordt **volledig** gehoord bij
      workout-einde (bug-fix: niet meer afgekapt)
- [ ] FinishedView "Herhaal" knop → countdown begint opnieuw,
      audio cues werken in 2e ronde
- [ ] FinishedView "Terug naar home" text-link → dismist, terug
      op Home
- [ ] HomeView totale tijd: geen middle-dots `·` meer onder de
      cijfer
- [ ] HomeView totale tijd voor langere workouts (>1 min): "1m 10s"
      op één regel, niet wrapped
- [ ] FinishedView stats card: drie kolommen op één regel uitgelijnd,
      ook voor lange workouts
- [ ] Sync: favoriet opslaan in vliegtuigmodus → online → staat op
      het 2e toestel na openen
- [ ] Sync: favoriet bewerken offline op toestel A → online → A's
      versie wint, ook na herstart van A
- [ ] Sync: favoriet verwijderen op toestel A → verdwijnt op toestel
      B bij openen / terug naar voorgrond
- [ ] Sync: verwijderen in vliegtuigmodus → komt niet terug na herstart
- [ ] Update over een bestaande build met favorieten: niets verdwijnt
      (SwiftData-migratie van de nieuwe velden)
- [ ] Timer: 8×(30/15)-workout eindigt binnen ~1s van de geplande
      totale tijd
- [ ] Paywall: app starten in vliegtuigmodus → paywall toont
      "Opnieuw proberen" → online → tik → prijs verschijnt, aankoop werkt
- [ ] Sign-in: inloggen met Supabase onbereikbaar → melding +
      "Synchronisatie niet verbonden" in Account → opnieuw verbinden werkt
