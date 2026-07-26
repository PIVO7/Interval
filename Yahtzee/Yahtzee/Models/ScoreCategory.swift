import Foundation

enum ScoreCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case ones
    case twos
    case threes
    case fours
    case fives
    case sixes
    case threeOfAKind
    case fourOfAKind
    case fullHouse
    case smallStraight
    case largeStraight
    case yahtzee
    case chance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ones: return "Enen"
        case .twos: return "Tweeën"
        case .threes: return "Drieën"
        case .fours: return "Vieren"
        case .fives: return "Vijven"
        case .sixes: return "Zessen"
        case .threeOfAKind: return "3 dezelfde"
        case .fourOfAKind: return "4 dezelfde"
        case .fullHouse: return "Full house"
        case .smallStraight: return "Kleine straat"
        case .largeStraight: return "Grote straat"
        case .yahtzee: return "Yahtzee"
        case .chance: return "Chance"
        }
    }

    var isUpper: Bool {
        switch self {
        case .ones, .twos, .threes, .fours, .fives, .sixes:
            return true
        default:
            return false
        }
    }

    static let upper: [ScoreCategory] = [.ones, .twos, .threes, .fours, .fives, .sixes]
    static let lower: [ScoreCategory] = [
        .threeOfAKind, .fourOfAKind, .fullHouse, .smallStraight, .largeStraight, .yahtzee, .chance
    ]
}
