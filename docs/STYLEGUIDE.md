# Interval — Styleguide

Referentie voor de visuele taal van Interval, bedoeld om dezelfde stijl toe te
passen op andere PIVO7-apps (o.a. Pump). Alle waarden komen rechtstreeks uit de
code (`Interval/Theme/`); bij twijfel is de code de bron van waarheid.

## 1. Merkgevoel

Warm, zacht en tactiel. Geen hard tech-blauw of neongroen maar koraal, amber en
salie op crème — eerder "yogastudio" dan "sportschool". Vormen zijn rond
(capsules, continuous corners), typografie is SF Rounded, en op iOS 26 doet
Liquid Glass het zware werk voor diepte en glans. Interactie voelt fysiek:
alles wat tapbaar is drukt zichtbaar in en geeft een haptic.

## 2. Kleur

### Merkkleuren

| Token | Hex | Gebruik |
|---|---|---|
| `coral` | `#E8826B` | Primair merk, work-fase, accenten |
| `amber` | `#F4B860` | Secundair merk, gradient-partner van coral |
| `sage` | `#A8B89C` | Rust/kalmte, rest-fase |
| `cream` | `#FAF6F1` | Lichte achtergrond |

### Diepe varianten (onderste gradient-stops)

| Token | Hex | Gebruik |
|---|---|---|
| `coralDeep` | `#C76A48` | Onderkant work-gradient, schaduwkleur CTA |
| `sageDeep` | `#5B8071` | Onderkant rest-gradient |
| `forestDeep` | `#3D6353` | Finish/celebratie-gradient |

### Dark mode

| Token | Hex |
|---|---|
| `darkBg` | `#1C1A18` (warm bijna-zwart, geen koud grijs) |
| `darkCard` | `#2A2724` |

### Tekst

| Token | Light | Dark |
|---|---|---|
| `textPrimary` | `#2B2B2B` | `white 0.96` |
| `textSecondary` | `#7A7A7A` | `white 0.65` |
| `error` | `#D9534F` | idem |

### Tekstveilige tinten (belangrijk!)

De basis-merkkleuren halen als **tekst** op crème/wit maar ~1.9–2.5:1 contrast.
Gebruik daarom aparte donkere tekstvarianten (≥4.5:1 op crème); in dark mode
volstaan de basistinten al:

| Token | Light (tekst) | Dark (tekst) |
|---|---|---|
| `coralText` | `#AC5535` | `#E8826B` |
| `amberText` | `#96631A` | `#F4B860` |
| `sageText` | `#567A64` | `#A8B89C` |

Vuistregel: basistint voor **vlakken en iconen**, `*Text`-variant voor
**tekst en tint van glazen knoppen**.

## 3. Gradients

Altijd twee stops, `topLeading → bottomTrailing`.

- **buttonGradient** (`AppTheme`): `#D96A4E → #C07E24`. Verdiepte
  coral→amber-run voor CTA's en icon-cirkels met wit label: houdt ≥3.3:1
  tegen wit over de hele run. Gebruik nooit de felle basistinten onder
  witte tekst.
- **Fase-gradients** (`PhaseTheme`): `base → deep` per work/rest/finished-
  fase; de default "Koraal" is `coral → coralDeep` (work) en `sage →
  sageDeep` (rest). Witte tekst steunt op de diepe onderste stop plus grote,
  vette cijfers. Themavarianten (Pro) blijven binnen dit contrast-envelope;
  warm = work, koel = rest.

## 4. Typografie

Alles is **SF Rounded** (`design: .rounded`) via Dynamic Type-stijlen; alleen
hero-cijfers krijgen vaste maten.

| Rol | Stijl |
|---|---|
| Schermtitel | large navigation title (+ `navigationSubtitle` op iOS 26) |
| Rijtitel / knoplabel | `.headline` rounded semibold |
| Waarde-chip | `.body` rounded bold + `.monospacedDigit()` |
| Sectiekop | `.subheadline` rounded semibold |
| Bijschrift | `.caption` / `.footnote` rounded |
| Timer (hero) | vaste maat (±96pt), **heavy** rounded, monospacedDigit |
| Celebratie ("GO!") | **black** rounded, vaste hero-maat |

Vuistregels: cijfers altijd `monospacedDigit()`; gewichten van semibold t/m
black — regular alleen voor lopende tekst; geen custom fonts.

## 5. Vorm & ruimte

- **Corner radii**: kaarten 24 (continuous), inzetblokken 18, kleine
  elementen 12–14. Knoppen en chips zijn **capsules**.
- **Spacing-ritme**: 4/6/8 micro, 10/14/16 binnen componenten, 20+ tussen
  secties. Rijen: `.padding(.horizontal, 18).padding(.vertical, 14)`.
  Schermmarge: 16pt horizontaal.
- **Kaarten** (`softCard`): witte/darkCard fill, radius 24, schaduw
  `black 6% / radius 18 / y 8` — zacht en laag-contrast.

## 6. Liquid Glass (iOS 26+) met fallbacks

Elke glass-API zit achter `#available(iOS 26.0, *)` met een fallback die de
layout identiek houdt:

- **Primaire CTA**: wit label, `glassEffect(.clear.interactive(), in: .capsule)`
  óver `Capsule().fill(buttonGradient)`. `.clear` glas houdt de gradient
  verzadigd en voegt de speculaire rand toe; `.regular` zou het oranje
  "verfrosten" naar dof baksteen — niet doen. Fallback: gradient-capsule +
  schaduw `coralDeep 35% / radius 10 / y 6`.
- **Secundaire knop**: `.buttonStyle(.glass)` + `.buttonBorderShape(.capsule)`
  + `.tint(coralText)`. Fallback: platte tekstknop in `coralText`.
- **Controls op fase-gradients**: `liquidGlassSurface(in:fallbackOpacity:)` —
  glas op iOS 26, translucent wit eronder.
- **Merk-medaillon** (`BrandIconCircle`): witte glyph, `glassEffect(.clear, in:
  .circle)` over `buttonGradient`-cirkel, glyph-schaduw `black 25% / 3 / y 2`.

## 7. Motie

Twee gedeelde curves (`Animation+` extensies) — voeg er geen derde toe:

- `appSmooth` — spring response 0.42, damping 0.86. Voor fase-overgangen en
  layout.
- `appBounce` — spring response 0.5, damping 0.65. Alleen voor celebratie
  (trofee, GO!, nudge-pulse).
- **Press feedback**: overal. Grote CTA's: scale 0.97 + opacity 0.85, easeOut
  0.15s (`PressableButtonStyle`). Rijen: scale 0.985 + primary-6%-highlight,
  easeOut 0.12s. Snel en strak, niet "levend".
- **Accordion-transition**: scale vanaf 0.95 verankerd `.top` + opacity, zodat
  content uit de getapte rij lijkt te groeien.

## 8. Haptiek & audio

Core Haptics met een klein vocabulaire van transients:

| Moment | intensity / sharpness |
|---|---|
| Licht (tik, laatste-3-sec) | 0.45 / 0.65 |
| Zwaar (fasewissel) | 0.80 / 0.55 |
| Zacht/succes | 0.50 / 0.30 |

Gecombineerd met spraak-countdown ("three, two, one — GO") en fasesignalen;
haptics spelen ook als audio gedempt is.

## 9. App-icoon (Liquid Glass, Icon Composer)

- `.icon`-package met gelaagde glyphs: aparte SVG-lagen (bij Interval: ring,
  wijzer, kroon) in **solid wit**, alle met `glass: true`, specular en
  combined lighting.
- Hoofdvorm: translucency **0.72**, blur-material **0.35** — de gradient
  schemert erdoor ("glassy", niet "frosted"). Detail-lagen: translucency
  0.15–0.2, blur 0.2, zodat ze leesbaar blijven.
- Achtergrond: lineaire merk-gradient (`coral → amber`-familie) met een
  donkerdere variant voor dark appearance; fill-specializations van de lagen
  op wit zodat tinted/clear correct rendert.
- Platte 1024-PNG in `Assets.xcassets` blijft de iOS 18-fallback.
- In-app echo: `BrandIconCircle` (zie §6).

## 10. Copy & toon

- Nederlands als basistaal (ook EN/FR), **je-vorm**, kort en direct:
  "Verder zonder account", "Start training".
- CTA's zijn werkwoorden; geen uitroeptekens buiten celebratiemomenten.
- Schermintro's via `navigationSubtitle` (iOS 26), niet als losse bodytekst.

## 11. Toepassen op een nieuwe app (Pump)

1. Kopieer `AppTheme.swift`, `Animations.swift` en `BrandIconCircle.swift` als
   vertrekpunt; vervang eventueel de merk-hexes maar behoud de structuur
   (basis + deep + `*Text`-varianten + buttonGradient) en de warme neutralen.
2. Behoud SF Rounded, de capsule-CTA met `.clear` glas over gradient, softCard
   (24/continuous) en de twee animatiecurves.
3. Bouw het icoon als gelaagd Icon Composer-package volgens §9.
4. Bewaak de twee contrastregels: `*Text`-tinten voor tekst, `buttonGradient`
   onder witte labels.
