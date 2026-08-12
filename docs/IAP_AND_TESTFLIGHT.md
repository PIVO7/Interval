# In-app aankoop aanmaken + sandbox/TestFlight testen

De "Interval Pro" unlock. Product-ID in de code: **`com.superapp.interval.pro_unlock`**
(zie `StoreManager.unlockProductID` en `ProUnlock.storekit`). Dit ID moet overal
exact gelijk zijn — het kan na aanmaken niet meer wijzigen.

---

## Vooraf (eenmalig, anders laadt de aankoop niet)

1. **Apple Developer Program** actief (€99/jaar).
2. **App-record** bestaat in App Store Connect met bundle-ID `com.superapp.interval`.
   (App Store Connect → Apps → + → New App, als die er nog niet is.)
3. ⚠️ **Paid Apps Agreement actief** — App Store Connect → *Business* → onderteken
   de "Paid Applications Agreement" en vul bank- + belastinggegevens in.
   Zonder dit geeft StoreKit een **lege productlijst** terug, óók in sandbox/TestFlight.

---

## Deel 1 — De IAP aanmaken in App Store Connect

1. App Store Connect → **Apps** → jouw app → zijbalk **Monetization → In-App Purchases** → **(+)**.
2. **Type:** Non-Consumable.
3. **Reference Name:** `Interval Pro Unlock` (alleen intern zichtbaar).
4. **Product ID:** `com.superapp.interval.pro_unlock`  ← exact dit, niet wijzigbaar.
5. **Price:** kies het prijspunt (bv. €4,99-tier).
6. **Localizations:** voeg minstens NL (+ EN) toe:
   - Display Name: `Interval Pro`
   - Description: bv. "Bewaar en hergebruik onbeperkt benoemde favoriete workouts en
     ontgrendel kleurthema's."
7. **App Store Review Information:** upload een **screenshot van de paywall** (verplicht
   voor review) + korte reviewnotitie.
8. **Save.** Status wordt **"Ready to Submit"**.

> "Ready to Submit" volstaat voor sandbox/TestFlight. Voor productie wordt de IAP
> de **eerste keer** samen met een app-versie meegestuurd ter review (koppel de IAP
> aan de versie onder "In-App Purchases and Subscriptions" bij die versie).

---

## Deel 2 — Sandbox testen (gratis, geen echte betaling)

### A. Maak een sandbox-testaccount
1. App Store Connect → **Users and Access** → **Sandbox** → **Test Accounts** → **(+)**.
2. Gebruik een e-mail die **nog geen Apple ID** is (een `+alias` werkt, bv.
   `jij+sandbox1@pivo7.be`). Stel wachtwoord + **regio** in (regio bepaalt de munt;
   kies je doelmarkt, bv. Nederland/België).
3. Save.

### B. Op een echt toestel
1. Build & install via **Xcode** op je toestel (of via TestFlight — zie deel 3).
2. ⚠️ **Belangrijk bij Xcode-builds:** standaard gebruikt het schema het lokale
   `ProUnlock.storekit`-bestand (handig, maar dat is *niet* de echte sandbox).
   Wil je tegen de **echte App Store Connect sandbox** testen, zet dan:
   *Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → **None***.
3. Log je sandbox-account in: **Instellingen → Developer → Sandbox Apple Account**
   (iOS 16+). Log **niet** uit bij je echte Apple ID onder Media & Aankopen.
4. Start de app → trigger de paywall (Opslaan als favoriet / een thema) → tik kopen →
   sandbox-dialoog ("je wordt niet belast") → bevestig → **Pro ontgrendeld, €0**.
5. Test ook **"Herstel aankopen"** in Account.

### C. Opnieuw de vergrendelde staat testen
Een non-consumable blijft "gekocht" voor dat sandbox-account. Om de **gratis/locked**
staat opnieuw te zien: gebruik een **tweede sandbox-tester**, of wis de aankoop­geschiedenis
via Instellingen → Developer → Sandbox-account → Reset.

### Nu al testen (zonder App Store Connect)
De `ProUnlock.storekit`-config zit in het schema, dus in de **simulator / Xcode** werkt
de volledige koop+herstel-flow nu meteen gratis — geen App Store Connect nodig.
(Resetten: tijdens het draaien in Xcode → **Debug → StoreKit → Manage Transactions** → Delete.)

---

## Deel 3 — TestFlight (gratis voor alle testers, vanzelf)

1. In Xcode: **Product → Archive** (Release) → **Distribute App → TestFlight** → upload.
2. App Store Connect → jouw app → **TestFlight** → voeg testers toe
   (Internal = direct; External = korte beta-review nodig).
3. Testers installeren via de TestFlight-app.
4. **In TestFlight draaien IAP's automatisch in sandbox** → testers gebruiken hun
   **eigen Apple ID**, worden **niet belast**, en hoeven géén sandbox-account te maken.
   De koopdialoog vermeldt expliciet dat het gratis is.

> Het lokale `ProUnlock.storekit` wordt in TestFlight/productie automatisch genegeerd —
> daar geldt altijd de echte (sandbox- resp. productie-)omgeving.

---

## Gratis toegang geven buiten TestFlight (optioneel)
Zodra de app **live** is: App Store Connect → jouw app → **Monetization → Offer Codes**
(of promo codes) → genereer tot 100 gratis codes die de Pro-unlock vrijspelen — handig
voor pers, vrienden of reviewers.

---

## Veelvoorkomende valkuilen
- **Lege productlijst / knop werkt niet** → Paid Apps Agreement niet actief, of Product-ID
  komt niet exact overeen.
- **Xcode toont steeds "gratis" lokaal** → het schema gebruikt `ProUnlock.storekit`; zet
  StoreKit Configuration op *None* om tegen echte sandbox te testen.
- **Sandbox vraagt steeds om inloggen** → stel het sandbox-account in onder
  Instellingen → Developer, niet onder je echte Media & Aankopen-account.
