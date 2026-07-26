import Foundation

enum YahtzeeScorer {
    static let upperBonusThreshold = 63
    static let upperBonusPoints = 35
    static let yahtzeePoints = 50
    static let yahtzeeBonusPoints = 100
    static let fullHousePoints = 25
    static let smallStraightPoints = 30
    static let largeStraightPoints = 40

    static func counts(for dice: [Int]) -> [Int: Int] {
        Dictionary(grouping: dice, by: { $0 }).mapValues(\.count)
    }

    static func isYahtzee(_ dice: [Int]) -> Bool {
        guard dice.count == 5 else { return false }
        return Set(dice).count == 1
    }

    static func score(category: ScoreCategory, dice: [Int], asJoker: Bool = false) -> Int {
        precondition(dice.count == 5)
        let values = dice.sorted()
        let tally = counts(for: values)

        if asJoker {
            switch category {
            case .ones: return values.filter { $0 == 1 }.reduce(0, +)
            case .twos: return values.filter { $0 == 2 }.reduce(0, +)
            case .threes: return values.filter { $0 == 3 }.reduce(0, +)
            case .fours: return values.filter { $0 == 4 }.reduce(0, +)
            case .fives: return values.filter { $0 == 5 }.reduce(0, +)
            case .sixes: return values.filter { $0 == 6 }.reduce(0, +)
            case .threeOfAKind, .fourOfAKind, .chance:
                return values.reduce(0, +)
            case .fullHouse:
                return fullHousePoints
            case .smallStraight:
                return smallStraightPoints
            case .largeStraight:
                return largeStraightPoints
            case .yahtzee:
                return yahtzeePoints
            }
        }

        switch category {
        case .ones: return values.filter { $0 == 1 }.reduce(0, +)
        case .twos: return values.filter { $0 == 2 }.reduce(0, +)
        case .threes: return values.filter { $0 == 3 }.reduce(0, +)
        case .fours: return values.filter { $0 == 4 }.reduce(0, +)
        case .fives: return values.filter { $0 == 5 }.reduce(0, +)
        case .sixes: return values.filter { $0 == 6 }.reduce(0, +)
        case .threeOfAKind:
            return tally.values.contains(where: { $0 >= 3 }) ? values.reduce(0, +) : 0
        case .fourOfAKind:
            return tally.values.contains(where: { $0 >= 4 }) ? values.reduce(0, +) : 0
        case .fullHouse:
            let counts = Set(tally.values)
            return counts == [2, 3] ? fullHousePoints : 0
        case .smallStraight:
            return hasStraight(values, length: 4) ? smallStraightPoints : 0
        case .largeStraight:
            return hasStraight(values, length: 5) ? largeStraightPoints : 0
        case .yahtzee:
            return isYahtzee(values) ? yahtzeePoints : 0
        case .chance:
            return values.reduce(0, +)
        }
    }

    /// Classic joker rule: after a scored Yahtzee (50), later Yahtzees may fill
    /// other boxes. Upper face of the Yahtzee must be used first if still open.
    static func canUseJoker(dice: [Int], scorecard: Scorecard) -> Bool {
        guard isYahtzee(dice) else { return false }
        guard scorecard.scores[.yahtzee] == yahtzeePoints else { return false }
        return true
    }

    static func availableCategories(dice: [Int], scorecard: Scorecard) -> [ScoreCategory] {
        let open = ScoreCategory.allCases.filter { scorecard.scores[$0] == nil }
        guard canUseJoker(dice: dice, scorecard: scorecard), let face = dice.first else {
            return open
        }

        let upperForFace: ScoreCategory = {
            switch face {
            case 1: return .ones
            case 2: return .twos
            case 3: return .threes
            case 4: return .fours
            case 5: return .fives
            default: return .sixes
            }
        }()

        if open.contains(upperForFace) {
            return [upperForFace]
        }
        return open
    }

    static func pointsForPlacing(
        category: ScoreCategory,
        dice: [Int],
        scorecard: Scorecard
    ) -> (score: Int, yahtzeeBonus: Int) {
        let joker = canUseJoker(dice: dice, scorecard: scorecard) && category != .yahtzee
        let score = score(category: category, dice: dice, asJoker: joker)
        let bonus: Int
        if isYahtzee(dice), scorecard.scores[.yahtzee] == yahtzeePoints {
            bonus = yahtzeeBonusPoints
        } else {
            bonus = 0
        }
        return (score, bonus)
    }

    private static func hasStraight(_ values: [Int], length: Int) -> Bool {
        let unique = Array(Set(values)).sorted()
        guard unique.count >= length else { return false }
        for start in 0...(unique.count - length) {
            let slice = unique[start..<(start + length)]
            let first = slice.first!
            if zip(slice, first...).allSatisfy({ $0.0 == $0.1 }) {
                return true
            }
        }
        return false
    }
}
