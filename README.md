# Roundly (codebase: Interval)

Simpele, betrouwbare interval-timer voor iOS (work/rest/rounds) met stem-cues,
haptics en sync van favorieten via iCloud (SwiftData + CloudKit, geen account
of eigen server). De timer is
volledig gratis; favorieten en trainingskleuren zitten achter een eenmalige
"Roundly Pro"-aankoop (€4,99, non-consumable via StoreKit 2).

In de App Store en op het beginscherm heet de app **Roundly**. Het Xcode-project,
de targets en de bundle-ID (`com.superapp.interval`) heten bewust nog "Interval":
die zijn onzichtbaar voor gebruikers, en de bundle-ID en het IAP-product-ID
kunnen na registratie niet meer wijzigen.

## Project opzetten (verse clone)

1. **Vereisten:** Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
   (`brew install xcodegen`).

2. **Project genereren en openen:**

   ```bash
   xcodegen generate
   open "Interval.xcodeproj"
   ```

   `project.pbxproj` wordt gegenereerd uit `project.yml` — nieuwe bestanden
   toevoegen = opnieuw `xcodegen generate` draaien.

3. **Tests:** Cmd+U, of:

   ```bash
   xcodebuild test -project "Interval.xcodeproj" -scheme "Interval" \
     -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

## iCloud-sync

Favorieten (`WorkoutEntity`) synchroniseren via de privé-database van de
gebruiker in CloudKit-container `iCloud.com.superapp.interval`. Daardoor
geldt voor het model: geen `@Attribute(.unique)` en een standaardwaarde op
elke property.

- In Xcode → Signing & Capabilities moeten **iCloud (CloudKit)** met die
  container en **Push Notifications** aan staan (de entitlements staan al
  in `Interval.entitlements`).
- **Vóór de App Store-release:** in het
  [CloudKit Console](https://icloud.developer.apple.com) het schema van
  Development naar Production deployen ("Deploy Schema Changes"), anders
  synct de App Store-build niet.
- Sync testen kan op twee echte toestellen met hetzelfde iCloud-account;
  de simulator synct alleen als je er bij iCloud inlogt.

## Docs

Zie `docs/` — o.a. `HANDOVER.md` (architectuur), `AUDIO_ARCHITECTURE.md`
(cue-systeem), `IAP_AND_TESTFLIGHT.md` (Pro-unlock in App Store Connect
en TestFlight), `APP_STORE_COPY.md` (store-listing in NL/EN/FR) en
`PRIVACY.md` (privacybeleid — publiek hosten vóór submissie).

De Pro-unlock is actief: `StoreManager.freeForEveryone` staat op `false`.
Terug naar volledig gratis shippen = die ene vlag op `true` zetten.

Het iOS 26-icoon is `Interval/AppIcon.icon` (Icon Composer, Liquid Glass).
De platte 1024 PNG in `Assets.xcassets` blijft de fallback voor iOS 18.
Open het `.icon`-bestand in Icon Composer om glass, dark en tinted te tunen.
