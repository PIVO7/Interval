// swift-tools-version:6.0
//
// Linux / SwiftPM test harness for the Yahtzee app's platform-independent core.
//
// The shipping app is an Xcode iOS/SwiftUI project (see project.yml + README.md)
// and must be built/run on macOS with Xcode + the iOS Simulator. SwiftUI/UIKit
// are unavailable on Linux, so this package deliberately compiles ONLY the pure
// Foundation/Observation game logic (Models, Game, AI, Persistence) plus the
// existing unit tests, so the core can be built and tested on Linux (e.g. in a
// cloud agent / CI) without Xcode.
//
// This manifest does not affect the Xcode build: XcodeGen reads project.yml and
// globs the inner "Yahtzee" source folder; this file is ignored by that flow.

import PackageDescription

let package = Package(
    name: "Yahtzee",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Yahtzee", targets: ["Yahtzee"]),
        .executable(name: "YahtzeeDemo", targets: ["YahtzeeDemo"]),
    ],
    targets: [
        .target(
            name: "Yahtzee",
            path: "Yahtzee",
            // Everything importing SwiftUI cannot compile off Apple OSes, so it is
            // excluded here; `sources` then restricts the build to the pure
            // Foundation/Observation game logic.
            exclude: [
                "YahtzeeApp.swift",
                "Assets.xcassets",
                "Theme",
                "Screens",
                "Components",
            ],
            sources: ["Models", "Game", "AI", "Persistence"]
        ),
        .executableTarget(
            name: "YahtzeeDemo",
            dependencies: ["Yahtzee"],
            path: "Demo"
        ),
        .testTarget(
            name: "YahtzeeTests",
            dependencies: ["Yahtzee"],
            path: "Yahtzee Tests"
        ),
    ],
    // Match the app's SWIFT_VERSION (5.0) so the shared sources compile the same
    // way here as they do in Xcode (avoids Swift 6 strict-concurrency changes).
    swiftLanguageModes: [.v5]
)
