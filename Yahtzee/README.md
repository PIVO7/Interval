# Yahtzee (SwiftUI)

Nieuwe iOS-app voor kinderen: klassiek Yahtzee met profielen, lokale multiplayer en solo tegen de computer.

> Dit project staat naast de bestaande Interval-app in dezelfde repo, onder `Yahtzee/`. Het is een **apart Xcode-project**.

## Features

- **Profielen** — naam + aantal overwinningen en gespeelde spellen (lokaal opgeslagen)
- **Tegen elkaar** — 2–4 spelers, beurten op één apparaat
- **Tegen de computer** — 1 kind + eenvoudige AI
- **Klassiek scoreblad** — bovenkant (1–6 + bonus 35 bij ≥63), onderkant, Chance
- **Yahtzee-bonus** — 100 punten voor elke extra Yahtzee nadat de Yahtzee-rij op 50 staat (met joker-regel)
- **Dobbelanimatie** — korte roll-animatie bij gooien; tik om dobbelstenen vast te houden

## Openen in Xcode

Op een Mac:

```bash
cd Yahtzee
brew install xcodegen   # eenmalig, indien nodig
xcodegen generate
open Yahtzee.xcodeproj
```

Kies een simulator of iPhone, druk op Run.

Vereisten: Xcode 15+, iOS 17+.

## App-structuur

```
Yahtzee/
  project.yml                 # XcodeGen
  Yahtzee/
    YahtzeeApp.swift
    Models/                   # Dobbelsteen, scorecategorieën, profiel, scoreblad
    Game/                     # GameEngine + YahtzeeScorer
    AI/                       # ComputerAI
    Persistence/              # ProfileStore (JSON in Documents)
    Components/               # Dice, scoreblad, avatar
    Screens/                  # Home, Profiles, Setup, Game
    Theme/
  Yahtzee Tests/              # Scoring, AI, profielen, engine
```

## Spelregels (kort)

1. Maximaal **3 worpen** per beurt; dobbelstenen mogen vastgehouden worden.
2. Na de beurt moet één **leeg** vakje gekozen worden (ook met 0 punten).
3. **Bovenbonus**: 35 punten als enen…zessen samen ≥ 63.
4. **Yahtzee**: 50 punten. Elke volgende Yahtzee (terwijl Yahtzee=50) geeft **+100 Yahtzee-bonus** en mag als joker in een ander vak.

## Ontwerpkeuzes

| Onderdeel | Keuze |
|-----------|--------|
| UI-taal | Nederlands (voor de kids) |
| Data | Lokaal JSON, geen account/cloud |
| AI | Heuristiek: houdt veelvoorkomende ogen / straten vast, scoort sterke hands vroeg |
| Architectuur | `@Observable` game engine + SwiftUI views |

## Tests

In Xcode: `⌘U`, of:

```bash
xcodebuild test -project Yahtzee.xcodeproj -scheme Yahtzee -destination 'platform=iOS Simulator,name=iPhone 16'
```
