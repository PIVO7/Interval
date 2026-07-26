import Foundation

struct ComputerDecision: Equatable {
    var holdMask: [Bool]
    var shouldScore: Bool
    var category: ScoreCategory?
}

struct ComputerAI {
    func decide(dice: [Die], rollsRemaining: Int, scorecard: Scorecard) -> ComputerDecision {
        let values = dice.map(\.value)
        let open = YahtzeeScorer.availableCategories(dice: values, scorecard: scorecard)

        if rollsRemaining == 0 {
            return ComputerDecision(
                holdMask: dice.map(\.isHeld),
                shouldScore: true,
                category: bestCategory(values: values, open: open, scorecard: scorecard)
            )
        }

        // If we already have a strong scoreable Yahtzee / large straight, take it.
        if YahtzeeScorer.isYahtzee(values), open.contains(.yahtzee) || YahtzeeScorer.canUseJoker(dice: values, scorecard: scorecard) {
            return ComputerDecision(
                holdMask: Array(repeating: true, count: 5),
                shouldScore: true,
                category: bestCategory(values: values, open: open, scorecard: scorecard)
            )
        }

        let large = YahtzeeScorer.score(category: .largeStraight, dice: values)
        if large > 0, open.contains(.largeStraight) {
            return ComputerDecision(
                holdMask: Array(repeating: true, count: 5),
                shouldScore: true,
                category: .largeStraight
            )
        }

        if rollsRemaining == 1 {
            let best = bestCategory(values: values, open: open, scorecard: scorecard)
            let expected = best.map { YahtzeeScorer.pointsForPlacing(category: $0, dice: values, scorecard: scorecard).score } ?? 0
            // Keep rolling only if current best is weak and we still have a roll.
            if expected >= 20 {
                return ComputerDecision(holdMask: holdMaskFor(values: values), shouldScore: true, category: best)
            }
        }

        return ComputerDecision(
            holdMask: holdMaskFor(values: values),
            shouldScore: false,
            category: nil
        )
    }

    private func holdMaskFor(values: [Int]) -> [Bool] {
        let counts = YahtzeeScorer.counts(for: values)
        let bestFace = counts.max { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value < rhs.value
        }?.key

        // Prefer holding the most frequent face; for near-straights hold sequential.
        if let straightHold = straightHoldMask(values: values) {
            return straightHold
        }

        guard let bestFace else {
            return Array(repeating: false, count: values.count)
        }
        return values.map { $0 == bestFace }
    }

    private func straightHoldMask(values: [Int]) -> [Bool]? {
        let unique = Set(values)
        let candidates: [Set<Int>] = [
            [1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6],
            [1, 2, 3, 4, 5], [2, 3, 4, 5, 6]
        ]
        guard let best = candidates.max(by: { $0.intersection(unique).count < $1.intersection(unique).count }),
              best.intersection(unique).count >= 3 else {
            return nil
        }

        var used: [Int: Int] = [:]
        return values.map { value in
            let keep = best.contains(value) && (used[value] ?? 0) == 0
            if keep { used[value, default: 0] += 1 }
            return keep
        }
    }

    private func bestCategory(
        values: [Int],
        open: [ScoreCategory],
        scorecard: Scorecard
    ) -> ScoreCategory? {
        guard !open.isEmpty else { return nil }

        return open.max { lhs, rhs in
            let l = utility(category: lhs, values: values, scorecard: scorecard)
            let r = utility(category: rhs, values: values, scorecard: scorecard)
            if l == r {
                // Prefer dumping zeros into chance last; prefer upper when equal.
                return categoryPriority(lhs) < categoryPriority(rhs)
            }
            return l < r
        }
    }

    private func utility(category: ScoreCategory, values: [Int], scorecard: Scorecard) -> Double {
        let result = YahtzeeScorer.pointsForPlacing(category: category, dice: values, scorecard: scorecard)
        var score = Double(result.score + result.yahtzeeBonus)

        // Prefer scoring meaningful upper faces toward the bonus.
        if category.isUpper, result.score > 0 {
            score += 2
        }

        // Avoid wasting Yahtzee box on zero when alternatives exist.
        if category == .yahtzee, result.score == 0 {
            score -= 40
        }

        // Prefer not zeroing valuable fixed boxes early.
        if result.score == 0 {
            switch category {
            case .yahtzee, .largeStraight, .smallStraight, .fullHouse:
                score -= 15
            default:
                score -= 3
            }
        }

        return score
    }

    private func categoryPriority(_ category: ScoreCategory) -> Int {
        switch category {
        case .chance: return 0
        case .ones: return 1
        case .twos: return 2
        case .threes: return 3
        case .fours: return 4
        case .fives: return 5
        case .sixes: return 6
        case .threeOfAKind: return 7
        case .fourOfAKind: return 8
        case .fullHouse: return 9
        case .smallStraight: return 10
        case .largeStraight: return 11
        case .yahtzee: return 12
        }
    }
}
