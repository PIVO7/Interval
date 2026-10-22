# Interval — setup

## 1. Generate the Xcode project

```bash
xcodegen generate
open "Interval.xcodeproj"
```

Run `xcodegen generate` again any time you add/remove files or change
`project.yml`.

## 2. iCloud

Favorites sync through the user's private CloudKit database
(container `iCloud.be.pivot-studio.roundly`). In Xcode → Signing &
Capabilities, make sure **iCloud → CloudKit** (with that container) and
**Push Notifications** are enabled. Before shipping, deploy the CloudKit
schema from Development to Production in the CloudKit Console.

## 3. Bundle the ambient audio files

See [`Interval/Resources/Audio/README.md`](Interval/Resources/Audio/README.md)
for the seven required files, format, and licensing notes. The app runs fine
without them — unavailable sounds are skipped at runtime.

## 4. Localization

Strings live in [`Interval/Localizable.xcstrings`](Interval/Localizable.xcstrings).
Open the file in Xcode to add English translations alongside the Dutch
source. The build extracts new strings automatically because
`SWIFT_EMIT_LOC_STRINGS` is enabled in `project.yml`.

## 5. Build & run

Select the **Interval** scheme and run on an iPhone simulator (or device).
Without an iCloud account the app works the same, with favorites kept
on the device only.

## v1 scope summary

In v1:
- Set work/rest/rounds, start timer
- Background audio + signal tones + haptics
- Favorites persisted locally (SwiftData) + synced via iCloud (CloudKit)
- Dutch UI, English translation infrastructure ready

Not in v1: workout history, templates, coach→patient sharing, Apple Watch,
push notifications, payments.
