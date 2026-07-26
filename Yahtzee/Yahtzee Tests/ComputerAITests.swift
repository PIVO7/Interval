import XCTest
@testable import Yahtzee

final class ComputerAITests: XCTestCase {
    func testScoresYahtzeeWhenAvailable() {
        let ai = ComputerAI()
        let dice = (0..<5).map { _ in Die(value: 6) }
        var card = Scorecard()

        let decision = ai.decide(dice: dice, rollsRemaining: 2, scorecard: card)
        XCTAssertTrue(decision.shouldScore)
        XCTAssertEqual(decision.category, .yahtzee)
    }

    func testChoosesCategoryWhenNoRollsLeft() {
        let ai = ComputerAI()
        let dice = [1, 2, 3, 4, 6].map { Die(value: $0) }
        let decision = ai.decide(dice: dice, rollsRemaining: 0, scorecard: Scorecard())
        XCTAssertTrue(decision.shouldScore)
        XCTAssertNotNil(decision.category)
    }
}
