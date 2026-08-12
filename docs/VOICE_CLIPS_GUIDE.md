# Voice clips genereren — ElevenLabs walkthrough

Stap-voor-stap gids om de 8 voice cues voor `VoicePlayer` te
genereren via ElevenLabs, te post-processen, en in de app te droppen.

**Taal**: voice clips zijn in het **Engels**. Reden: Engels is de
universele "fitness vocabulary" (Go, Rest, Halfway zijn standaard in
trainings-cues wereldwijd), klinkt professioneler op een
internationaal niveau, en de stem-keuze in ElevenLabs is veel groter
voor Engels dan Nederlands. De app-UI blijft Nederlands — dat is een
veelvoorkomend pattern bij fitness-apps (Apple Workout, Strava,
Tabata Pro doen hetzelfde).

VoiceOver-announcements (geen audio, maar tekstuele accessibility
hints) blijven in het Nederlands via `Localizable.xcstrings`. Dat is
een aparte channel die voor blinde gebruikers in hun OS-taal werkt.

Verwachte tijdsinvestering: **30-45 minuten** end-to-end.

---

## Stap 1 — ElevenLabs account + plan

> **Pricing-disclaimer**: cijfers hieronder zijn van **juni 2026** —
> ElevenLabs herziet plannen geregeld. Verifieer op
> https://elevenlabs.io/pricing vóór je betaalt.

1. Ga naar https://elevenlabs.io en maak een account.
2. Twee plannen die werken voor onze use case:

   **Starter** (~$6/mo) — minimum voor App Store
   - Commerciële licentie (verplicht)
   - 30 000 credits/maand
   - Voor 8 cues × ~5 takes ruim voldoende (een cue als
     "Great work!" kost ~11 credits, je gebruikt waarschijnlijk
     <1000 totaal)

   **Creator** (~$11 eerste maand met 50% off, daarna ~$22) —
   meer marge
   - Commerciële licentie
   - 121 000 credits/maand
   - Access tot Pro Voices uit de Library
   - Nuttig als je veel takes wilt genereren of meerdere stemmen wilt
     vergelijken

   Voor v1: **Starter is genoeg**. Creator alleen als je meerdere
   voice-styles wilt vergelijken of premium voices wilt gebruiken.

3. Na het maken van de clips: **cancel het abonnement**. De
   gegenereerde audio blijft commercieel licensed (zie licentie-uitleg
   onderaan dit document).

> **Belangrijk**: Free tier (10 000 credits) heeft **geen**
> commerciële licentie — mag je niet in een App Store-app gebruiken.

---

## Stap 2 — Voice kiezen

Twee opties:

**A. Voice uit de Library** (snelst)
- Open **Voice Library** in het ElevenLabs dashboard
- Filter: Language = `English`, Accent = `American` (meest neutraal
  voor internationaal publiek) of `British` (voor premium feel),
  Use Case = `Sports` / `Conversational`
- Luister 5-10 stemmen. Zoek naar:
  - Warme grondtoon (geen scherpe/nasale stem)
  - Vriendelijke energie (geen drill sergeant, geen "gym bro")
  - Heldere articulatie (cues mogen niet wegvallen onder ducked music)
- Aanbevolen archetypes: "Friendly Fitness Coach", "Calm Confident
  Trainer", "Professional Wellness Voice". Vermijd "Energetic Hype
  Voice" — wordt te schreeuwerig over een workout.
- Voeg de stem toe aan je **My Voices**.

**B. Voice Design** (meer controle, ~5 min extra)
- Open **Voice Design**
- Beschrijving: `American English male, age 30-40, warm and
  confident, professional but approachable, calm authority, like a
  Nike Training Club coach — energetic without shouting, encouraging
  without being patronizing`
- Genereer 3 varianten, kies de beste.

> **Sekse-keuze**: voor fitness-cues werken zowel mannelijke als
> vrouwelijke stemmen — kies wat past bij je merkidentiteit. Apple
> Fitness+ wisselt af, Nike Training Club is meestal vrouwelijk,
> Strava intervalmodus is mannelijk. Geen statistisch beste keuze.

---

## Stap 3 — Cues genereren

Open **Text to Speech**, selecteer je gekozen stem, en genereer per
cue met de gespecificeerde tekst + settings.

### Per-cue spec

| Cue file              | Tekst             | Stability | Similarity | Style | Reden                                              |
| --------------------- | ----------------- | --------- | ---------- | ----- | -------------------------------------------------- |
| `cue_three.m4a`       | `Three.`          | 55        | 75         | 25    | Monotoon, voorspelbaar — countdown moet ritme zijn |
| `cue_two.m4a`         | `Two.`            | 55        | 75         | 25    | Idem                                               |
| `cue_one.m4a`         | `One.`            | 55        | 75         | 25    | Idem                                               |
| `cue_work_start.m4a`  | `Go!`             | 40        | 75         | 60    | Hoogste energie van alle cues                      |
| `cue_rest_start.m4a`  | `Rest.`           | 60        | 75         | 30    | Kalmerend, lager in toon                           |
| `cue_halfway.m4a`     | `Halfway.`        | 50        | 75         | 40    | Bemoedigend                                        |
| `cue_last_round.m4a`  | `Last round!`     | 45        | 75         | 55    | Aansporend, niet schreeuwen                        |
| `cue_finished.m4a`    | `Great work!`     | 50        | 75         | 50    | Warm enthousiasme                                  |

### Werkwijze per cue

1. Plak **alleen de tekst** in de Text-to-Speech box (niet het hele
   tabel-row — TTS leest letterlijk wat je erin plakt)
2. Zet Stability/Similarity/Style volgens tabel
3. Klik **Generate** → genereer **3-5 takes per cue** (verschillende
   takes klinken anders door subtiele randomness)
4. Luister + selecteer de beste take
5. **Download** als WAV (hoogste kwaliteit — m4a-export zit niet
   altijd in lagere plans)
6. Bestandsnamen tijdens download: `cue_three_take.wav`, etc.
   (we hernoemen na processing)

> **Tip**: voor "Three/Two/One" — neem ze in dezelfde sessie achter
> elkaar op zodat de toonhoogte en cadans consistent zijn. Plak dit
> in één tekstveld:
> ```
> Three.
>
> Two.
>
> One.
> ```
> (blank lines tussen → ElevenLabs interpreteert ze als aparte
> utterances). Daarna split je het bestand in 3 cues in Audacity.

### Verifieer uitspraak

Bij Engels zelden problemen, maar check toch:
- `Three` moet "thri:" zijn (lange ie, niet "tree")
- `Two` moet "tu:" zijn (niet "twoh")
- `One` moet "wʌn" zijn (niet "won-ee")
- `Go!` moet kort en energiek — niet "Gooo"
- `Halfway` accent op eerste lettergreep ("HALF-way")

Als de uitspraak fout is: regenereer met andere stem, of gebruik SSML:
```xml
<phoneme alphabet="ipa" ph="θriː">Three</phoneme>
```

---

## Stap 4 — Post-processing

WAV → m4a + normalisatie. Drie tools, kies de simpelste die werkt:

### Optie A — Auphonic (web-based, makkelijkst)

1. Ga naar https://auphonic.com (gratis: 2 uur audio/maand, ruim
   genoeg)
2. Maak een **Production** aan
3. Settings:
   - **Loudness target**: `-16 LUFS Mobile / Tablet`
   - **Output format**: `AAC (m4a)` at `96 kbps`, `Mono`, `22050 Hz`
   - **Leveler**: `Mid (Normal)`
   - **Noise reduction**: `Auto`
   - **Filtering**: highpass at `80 Hz` (snijdt low-end rommel)
4. Upload alle WAVs, processeer, download
5. Trim leading silence (zie stap 5)

### Optie B — ffmpeg (CLI, snelst als je het kent)

Per cue:
```bash
ffmpeg -i cue_three_take.wav \
  -af "highpass=f=80,loudnorm=I=-16:TP=-1.0:LRA=7" \
  -c:a aac -b:a 96k -ar 22050 -ac 1 \
  cue_three.m4a
```

`loudnorm` doet 2-pass normalisatie + true-peak limiter in één stap.

### Optie C — Logic Pro / GarageBand (als je dat al hebt)

1. Importeer WAV, knip per cue
2. Bus naar een output met **Adaptive Limiter** plugin (target -16 LUFS)
3. Export als AAC, 22.05 kHz, 96 kbps, mono

---

## Stap 5 — Leading/trailing silence trimmen

**Kritisch**: de cue moet direct hoorbaar zijn op het moment dat de
fase begint. Meer dan ~10 ms leading silence en de "Go!" valt
hoorbaar laat.

Open elk bestand in **Audacity** (gratis):
1. Zoom in op de start van de waveform
2. Selecteer alles vóór de eerste hoorbare audio (eerste piek)
3. Delete
4. Trailing silence ≤ 50 ms (natuurlijke ademhaling, niet meer)
5. Exporteer terug als m4a

Of via ffmpeg in één klap:
```bash
ffmpeg -i in.m4a -af "silenceremove=start_periods=1:start_silence=0.005:start_threshold=-50dB" out.m4a
```

---

## Stap 6 — Kwaliteitscheck

Voor je commit:

- [ ] Alle 8 bestanden < 80 KB elk
- [ ] Filenames exact: `cue_three.m4a`, `cue_two.m4a`, `cue_one.m4a`,
      `cue_work_start.m4a`, `cue_rest_start.m4a`, `cue_halfway.m4a`,
      `cue_last_round.m4a`, `cue_finished.m4a`
- [ ] In QuickTime: alle clips hoorbaar binnen 10 ms van play
- [ ] Volume voelt consistent tussen clips (niet één veel luider/zachter)
- [ ] Test op AirPods + telefoon-speaker — moet hoorbaar zijn op beide
- [ ] Test met Spotify aan in achtergrond — cues moeten boven de
      ducked muziek uitkomen
- [ ] Beluister "Three / Two / One" achter elkaar — moeten qua toon
      en cadans samen werken als één aftelling

---

## Stap 7 — In de app droppen

1. Drop alle 8 m4a-bestanden in:
   ```
   Interval/Resources/Audio/
   ```
   (of in een nieuwe `Voice/` submap — XcodeGen pakt het auto op)
2. Run `xcodegen generate` om de Xcode-project op te frissen
3. Stuur mij een seintje — ik vervang dan in
   `VoicePlayer.loadBuffers()` de synth-rendering met
   `AVAudioFile.read(into:)`. ~10 minuten werk, geen verdere refactor.

---

## Stap 8 — Voor andere talen later (NL, FR, DE…)

Mocht je later besluiten dat je toch een NL/FR/DE-variant wilt:

- Gebruik zelfde stem indien beschikbaar via **Multilingual v2**
  model (ondersteunt 29+ talen met consistente voice timbre)
- NL voorbeeld-teksten: `Drie.`, `Twee.`, `Eén.`, `Go!`, `Rust.`,
  `Halverwege.`, `Laatste ronde!`, `Goed gedaan!`
- Bestanden in `Interval/Resources/Audio/nl.lproj/`
- EN-bestanden verhuizen naar `Interval/Resources/Audio/en.lproj/`
- `Bundle.main.url(forResource:)` resolvet automatisch naar de
  juiste locale — geen code-wijziging nodig

Voor v1 is dit niet relevant — Engels werkt als universele
fitness-taal voor alle markten waar de app komt.

---

## Budget-samenvatting

> Prijzen juni 2026 — verifieer op https://elevenlabs.io/pricing

| Item                                      | Kost                        |
| ----------------------------------------- | --------------------------- |
| ElevenLabs Starter (1 maand)              | ~$6                         |
| (alternatief: Creator eerste maand 50%)   | ~$11                        |
| Auphonic Free                             | €0 (2u/mnd ruim genoeg)     |
| ffmpeg / Audacity                         | €0                          |
| **Totaal voor v1**                        | **~$6**                     |
| Extra talen later (zelfde maand)          | €0                          |

Versus voice talent: €100-400 + 24-72h wachten.
Versus zelf opnemen: €100-250 mic + 4-6 uur leren.

---

## Licentie-archivering — verplicht doen vóór je cancelt

ElevenLabs verleent de commerciële licentie op het moment van
**genereren**, niet op het moment van **gebruiken**. Dat betekent:
- Audio die je genereert op een betaald plan (Starter+) → mag je voor
  altijd commercieel gebruiken, ook na cancellation.
- Audio die je genereert op Free → enkel persoonlijk gebruik.

Voor toekomstige App Store reviews of dispuut-situaties wil je proof
van je commerciële licentie kunnen tonen. Bewaar daarom:

### Wat archiveren

Maak een map `docs/voice_clips_license/` met:

1. **Factuur PDF** — download via ElevenLabs dashboard →
   Subscription → Billing History. Bestandsnaam:
   `elevenlabs_starter_invoice_YYYY-MM-DD.pdf`

2. **Screenshot van plan-status** op het moment van genereren —
   Subscription-pagina met datum + "Starter" plan zichtbaar.
   Bestandsnaam: `plan_status_YYYY-MM-DD.png`

3. **Generatie-log** — een markdown-bestand met per cue:
   - Datum + tijd van generatie
   - Voice ID + naam
   - Exacte prompt-tekst
   - Settings (Stability, Similarity, Style)
   - Take-nummer dat je gekozen hebt

   Template (`generation_log.md`):
   ```markdown
   # Voice clip generation log

   - **Plan tijdens generatie**: ElevenLabs Starter (~$6/mo)
   - **Datum**: 2026-XX-XX
   - **Voice**: Adam (ID: pNInz6obpgDQGcFmaJgB)
   - **Model**: eleven_multilingual_v2
   - **Taal**: English (US)

   ## Cues

   ### cue_three.m4a
   - Prompt: `Three.`
   - Settings: Stability 55 / Similarity 75 / Style 25
   - Take 3 gekozen

   ### cue_two.m4a
   - ...
   ```

4. **Snapshot van Terms of Service** — open
   https://elevenlabs.io/terms en bewaar als PDF (browser → Print →
   Save as PDF). De passage over "commercial use rights survive
   subscription cancellation" markeren. Bestandsnaam:
   `elevenlabs_tos_YYYY-MM-DD.pdf`

### Wanneer dit relevant wordt

- **App Store review** vraagt soms expliciet naar audio-licenties bij
  apps met spoken content. Je kunt dan in de App Review notes naar
  de archived files verwijzen.
- **Apple Privacy / Content Disclosure** — als ze later AI-disclosure
  vereisen, weet je exact welke clips AI-generated zijn.
- **Dispuut** — als een gebruiker of derde partij ooit een claim
  inlegt over de audio, heb je proof of license.

### Quick checklist vóór cancellation

- [ ] Factuur PDF gedownload + in `docs/voice_clips_license/`
- [ ] Plan-status screenshot in dezelfde map
- [ ] `generation_log.md` ingevuld met alle 8 cues
- [ ] ToS PDF gedownload
- [ ] `docs/voice_clips_license/` gecommit naar git
- [ ] Pas dan: subscription cancellen

---

## Nieuwe cues toevoegen in v1.x

Wil je later "Halfway" verbeteren of een extra taal toevoegen?
Workflow:

1. Pak opnieuw **1 maand Starter** (~$6, verifieer actuele prijs)
2. Genereer + post-process zoals beschreven
3. **Voeg toe** aan `generation_log.md` (niet overschrijven — append)
4. Nieuwe factuur + plan-status screenshot in
   `docs/voice_clips_license/`
5. Cancel weer

Belangrijk: ook al staan oude cues onder je oude licentie, **nieuwe**
generaties moeten onder een actief betaald plan gebeuren. Anders
hebben die specifieke clips geen commerciële licentie.
