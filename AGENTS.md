# AGENTS.md

## Cursor Cloud specific instructions

This repo contains **two iOS apps** built as Xcode projects (XcodeGen):

- `Interval v1/` — interval timer (uses the `supabase-swift` package + a gitignored
  `SupabaseConfig.swift`; needs Sign in with Apple). See `README.md` / `SETUP.md`.
- `Yahtzee/` — standalone kids' Yahtzee SwiftUI app. See `Yahtzee/README.md`.

### Platform reality (important)

The shipping apps are **iOS/SwiftUI** and can only be **built and run on macOS**
with Xcode + the iOS Simulator (`xcodegen generate`, then `xcodebuild`/Xcode).
SwiftUI/UIKit and the iOS Simulator do **not** exist on Linux, so the full GUI
apps cannot be built or run in the cloud (Linux) VM. Do not attempt `xcodebuild`
here — there is no Xcode.

### What *can* run on Linux (cloud VM)

The `Yahtzee` app's core game logic (`Yahtzee/Yahtzee/Models`, `Game`, `AI`,
`Persistence`) is pure `Foundation`/`Observation` and is fully testable on Linux.
A SwiftPM harness at `Yahtzee/Package.swift` compiles **only** that logic (SwiftUI
files are excluded) as module `Yahtzee`, wires the existing `Yahtzee Tests/`
XCTest suite, and provides a headless demo. This manifest is Linux/CI-only and
does not affect the Xcode build (XcodeGen still reads `Yahtzee/project.yml`).

Commands (run from `Yahtzee/`):

- Test: `swift test`
- Headless end-to-end demo (plays a full game, exercises engine + AI + scorer +
  profile persistence): `swift run YahtzeeDemo`
- Build only: `swift build`

There is no dedicated linter (no SwiftLint config); the Swift compiler's warnings
are the lint signal. `Interval v1` has no Linux-runnable harness (SwiftUI +
Supabase + Sign in with Apple throughout).

### Toolchain notes

- Swift is installed via `swiftly` (toolchain 6.3.x) at
  `~/.local/share/swiftly`; its env is sourced from `~/.profile` and `~/.bashrc`
  (`swift` is on `PATH` in interactive shells). If `swift` is ever missing, run
  `swiftly install latest` (or reinstall swiftly from
  https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz), and ensure
  these apt libs are present: `libcurl4-openssl-dev libpython3-dev libxml2-dev
  libncurses-dev libz3-dev gnupg2`.
- The `Yahtzee` SwiftPM package has **no external dependencies**, so there is
  nothing to fetch/refresh beyond the toolchain itself.
- The package is built in Swift 5 language mode (`swiftLanguageModes: [.v5]`) to
  match the app's `SWIFT_VERSION: 5.0`.
