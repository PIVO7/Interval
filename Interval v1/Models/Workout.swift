import Foundation

struct Workout: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var createdAt: Date = .now

    var totalSeconds: Int {
        rounds * workSeconds + max(0, rounds - 1) * restSeconds
    }

    var summary: String {
        // Swift-native localized interpolation — Localizable.xcstrings picks
        // up the source key automatically, no C-style format string needed.
        // Reuses `Int.asCompactDuration` so duration formatting stays in one
        // place (see Duration+Formatting).
        String(localized: "\(workSeconds.asCompactDuration) werk · \(restSeconds.asCompactDuration) rust · \(rounds) ronden")
    }

    static let placeholder = Workout(name: "Tabata 30/15", workSeconds: 30, restSeconds: 15, rounds: 8)
}
