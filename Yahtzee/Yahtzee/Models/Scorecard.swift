import Foundation

struct Scorecard: Equatable, Codable {
    var scores: [ScoreCategory: Int] = [:]
    var yahtzeeBonusTotal: Int = 0

    var upperSubtotal: Int {
        ScoreCategory.upper.compactMap { scores[$0] }.reduce(0, +)
    }

    var upperBonus: Int {
        upperSubtotal >= YahtzeeScorer.upperBonusThreshold ? YahtzeeScorer.upperBonusPoints : 0
    }

    var lowerSubtotal: Int {
        ScoreCategory.lower.compactMap { scores[$0] }.reduce(0, +)
    }

    var total: Int {
        upperSubtotal + upperBonus + lowerSubtotal + yahtzeeBonusTotal
    }

    var isComplete: Bool {
        ScoreCategory.allCases.allSatisfy { scores[$0] != nil }
    }

    var filledCount: Int {
        scores.count
    }

    mutating func place(category: ScoreCategory, score: Int, yahtzeeBonus: Int) {
        precondition(scores[category] == nil)
        scores[category] = score
        yahtzeeBonusTotal += yahtzeeBonus
    }
}
