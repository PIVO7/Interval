# Privacybeleid — Interval

_Laatst bijgewerkt: 12 augustus 2026_

Interval is een interval-timer-app voor coaches, kinesitherapeuten en
mensen die regelmatig HIIT/Tabata-style trainingen doen. We willen zo
min mogelijk persoonsgegevens verwerken, en als we het doen — alleen om
de app voor jou te laten werken. Geen tracking, geen advertenties,
geen verkoop van gegevens.

Dit document beschrijft welke gegevens we verzamelen, hoe we ze
gebruiken, en welke rechten je hebt.


## 1. Wie we zijn

**Verantwoordelijke voor de gegevensverwerking** (in de zin van
GDPR / AVG art. 4(7)):

Jelle Wauters
e-mail: [jelle@pivo7.be](mailto:jelle@pivo7.be)

Voor alle vragen over je gegevens, of om je rechten uit te oefenen
(zie sectie 7), gebruik dat e-mailadres.


## 2. Welke gegevens we verzamelen

### a. Inloggen via Sign in with Apple (optioneel)

Je kunt Interval volledig anoniem gebruiken (knop "Verder zonder
account" in de onboarding). Doe je dat, dan slaan we **geen
persoonsgegevens op een server op**. Alleen je workout-instellingen en
voorkeuren blijven lokaal op je apparaat.

Kies je voor "Sign in with Apple", dan ontvangen wij van Apple:

- een **anonieme gebruikers-ID** (Apple's `userIdentifier`,
  bv. `001234.abcdef1234567890.0000`),
- je **volledige naam** — alleen bij de eerste keer inloggen, en
  alleen als je daar toestemming voor geeft in Apple's dialoogvenster,
- een **e-mailadres** — kan je echte e-mail zijn of een door Apple
  gegenereerd "Private Relay" alias als je daarvoor kiest in dezelfde
  dialoog.

We slaan die gegevens op in onze database (zie sectie 4) zodat we je
opgeslagen workouts kunnen koppelen aan je account.

### b. Workouts die je opslaat als favoriet

Wanneer je een interval-schema (work / rest / aantal rondes) opslaat
als favoriet, slaan we het volgende op:

- de naam die je het schema geeft (bv. "Tabata 30/15"),
- de duur van de werkfases (seconden),
- de duur van de rustfases (seconden),
- het aantal rondes,
- de datum waarop je hem aangemaakt hebt.

Alleen lokaal als je niet ingelogd bent. Plus in onze cloud database
als je wel ingelogd bent.

### c. In-app aankoop (Interval Pro)

De eenmalige "Interval Pro"-aankoop verloopt volledig via Apple's
App Store (StoreKit). Wij ontvangen **geen betaalgegevens** — geen
kaartnummers, geen factuuradres, geen Apple-ID. Of je de aankoop
gedaan hebt wordt door Apple bijgehouden en door de app alleen
lokaal uitgelezen; wij slaan het niet op onze server op.

### d. Lokale voorkeuren

De volgende gegevens worden **alleen lokaal op je apparaat** opgeslagen,
in iOS' `UserDefaults`, en gaan nooit naar onze server:

- of je de onboarding al hebt gezien,
- welk omgevingsgeluid je laatst koos en op welk volume,
- of haptic feedback en signaaltonen aan staan,
- of je licht / donker / systeem-uiterlijk hebt geselecteerd.

### e. Wat we NIET verzamelen

- Geen locatie.
- Geen contactpersonen, foto's, of microfoon-data.
- Geen gezondheidsgegevens (geen hartslag of vergelijkbare data).
- Geen analytics-pixels, geen advertentie-IDs.
- Geen tracking tussen apps of websites.


## 3. Waarom we deze gegevens gebruiken

| Doel | Gegevens | Rechtsgrond (GDPR art. 6) |
|---|---|---|
| Je account herkennen tussen apparaten | Apple user-ID, naam, e-mail | Uitvoering van de overeenkomst (art. 6.1.b) |
| Je opgeslagen workouts synchroniseren | Workout-naam + instellingen | Uitvoering van de overeenkomst (art. 6.1.b) |
| Je per e-mail antwoorden op vragen die je stelt | E-mailadres | Gerechtvaardigd belang (art. 6.1.f) |

We doen **geen profiling**, **geen geautomatiseerde besluitvorming**
op basis van je gegevens, en gebruiken je gegevens **niet voor
marketing** (we sturen je nooit een nieuwsbrief tenzij je je daar
expliciet op inschrijft — wat we momenteel niet eens aanbieden).


## 4. Met wie we gegevens delen

Wij verkopen je gegevens niet en delen ze niet met derden voor
commerciële doeleinden. We gebruiken wel de volgende **subverwerkers**
om de app technisch te laten werken:

### Supabase (database + authenticatie)

Onze backend draait op [Supabase](https://supabase.com), een
PostgreSQL-as-a-service provider. Supabase bewaart je account-gegevens
en opgeslagen workouts op servers in de **Europese Unie** (regio
`eu-central-1`, Frankfurt). Supabase is verwerker, wij zijn
verantwoordelijke. Hun privacybeleid:
[supabase.com/privacy](https://supabase.com/privacy).

### Apple

- **Sign in with Apple**: Apple authentiseert je identiteit. Wij
  ontvangen alleen wat je in het Apple-dialoogvenster goedkeurt
  (sectie 2.a).
- **App Store / StoreKit**: de eenmalige Interval Pro-aankoop wordt
  volledig door Apple afgehandeld (sectie 2.c). Apple's privacybeleid:
  [apple.com/legal/privacy](https://www.apple.com/legal/privacy).

Geen andere derde partijen ontvangen je gegevens.


## 5. Hoe lang we gegevens bewaren

| Categorie | Bewaartermijn |
|---|---|
| Account-gegevens (Apple user-ID, naam, e-mail) | Zo lang je account actief is |
| Opgeslagen workouts | Zo lang je account actief is, of tot je ze handmatig verwijdert |
| Lokale voorkeuren | Tot je de app verwijdert van je apparaat |

Als je je account wilt laten verwijderen — zie sectie 7. We verwijderen
dan alles binnen 30 dagen.


## 6. Beveiliging

- Alle communicatie tussen de app en onze backend gaat via **HTTPS / TLS 1.2+**.
- Database-tabellen hebben **Row Level Security (RLS)**: je eigen
  gegevens zijn alleen toegankelijk vanuit jouw geauthenticeerde
  sessie.
- Je privé Apple-wachtwoord raken wij nooit aan — Sign in with Apple
  gebruikt alleen identity tokens.


## 7. Jouw rechten

Onder de Europese Algemene Verordening Gegevensbescherming (AVG / GDPR)
heb je het recht om:

- **inzage** te vragen in welke gegevens we van jou hebben (art. 15),
- **rectificatie** te vragen als gegevens incorrect zijn (art. 16),
- **verwijdering** te vragen van je gegevens (art. 17 — "right to be
  forgotten"),
- **beperking** van de verwerking te vragen (art. 18),
- **overdraagbaarheid** van je gegevens te vragen — wij sturen je dan
  een JSON-bestand met alles wat we van je hebben (art. 20),
- **bezwaar te maken** tegen onze verwerking (art. 21),
- een **klacht in te dienen** bij de Gegevensbeschermingsautoriteit
  (GBA / Belgische DPA — [gegevensbeschermingsautoriteit.be](https://www.gegevensbeschermingsautoriteit.be))
  of de toezichthouder in je eigen EU-land.

Stuur een mail naar [jelle@pivo7.be](mailto:jelle@pivo7.be) en we
verwerken je verzoek binnen 30 dagen.

Wil je gewoon je hele account weg? Mail "Verwijder mijn account" naar
het bovenstaande adres met je Apple user-ID of de e-mail waarmee je
Sign in with Apple gedaan hebt, en we doen dat binnen 7 werkdagen.


## 8. Wijzigingen aan dit beleid

Als we dit beleid materieel wijzigen (bv. nieuwe subverwerkers, nieuwe
gegevenscategorieën) updaten we de "Laatst bijgewerkt" datum bovenaan
en notificeren we ingelogde gebruikers per e-mail. Triviale wijzigingen
(typo's, verduidelijkingen) verschijnen gewoon hier zonder notificatie.

De huidige en eerdere versies blijven raadpleegbaar via de
versiegeschiedenis van deze pagina.


## 9. Contact

Vragen? Klachten? Mail [jelle@pivo7.be](mailto:jelle@pivo7.be).

---

_Korte versie voor wie haast heeft: we slaan alleen je Apple-naam,
e-mail, en favorieten op een Europese Supabase server op (als je
inlogt). Daar gebeurt verder niets mee. Geen advertenties, geen
analytics, geen verkoop. Mail ons als je je account weg wilt._
