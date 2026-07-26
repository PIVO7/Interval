import Foundation

struct PlayerProfile: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    var name: String
    var wins: Int
    var gamesPlayed: Int
    var avatarColorIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        wins: Int = 0,
        gamesPlayed: Int = 0,
        avatarColorIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.wins = wins
        self.gamesPlayed = gamesPlayed
        self.avatarColorIndex = avatarColorIndex
        self.createdAt = createdAt
    }

    static let computerID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C0")!

    static var computer: PlayerProfile {
        PlayerProfile(
            id: computerID,
            name: "Computer",
            wins: 0,
            gamesPlayed: 0,
            avatarColorIndex: 5
        )
    }

    var isComputer: Bool { id == Self.computerID }
}
