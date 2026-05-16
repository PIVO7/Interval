import Foundation

struct Workout: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var createdAt: Date = Date()

    var totalSeconds: Int {
        rounds * workSeconds + max(0, rounds - 1) * restSeconds
    }

    var summary: String {
        String(
            format: NSLocalizedString("%@ werk · %@ rust · %lld ronden",
                                     comment: "Workout summary line (work duration, rest duration, rounds)"),
            formatted(workSeconds),
            formatted(restSeconds),
            rounds
        )
    }

    private func formatted(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    static let placeholder = Workout(name: "Tabata 30/15", workSeconds: 30, restSeconds: 15, rounds: 8)
}
