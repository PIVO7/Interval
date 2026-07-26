import Foundation

struct Die: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    var value: Int
    var isHeld: Bool

    init(id: UUID = UUID(), value: Int = 1, isHeld: Bool = false) {
        self.id = id
        self.value = min(max(value, 1), 6)
        self.isHeld = isHeld
    }

    mutating func roll(using generator: inout some RandomNumberGenerator) {
        guard !isHeld else { return }
        value = Int.random(in: 1...6, using: &generator)
    }
}

typealias Dice = [Die]
