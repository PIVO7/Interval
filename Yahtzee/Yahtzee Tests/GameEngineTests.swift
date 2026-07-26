import XCTest
@testable import Yahtzee

@MainActor
final class GameEngineTests: XCTestCase {
    func testHumanCanRollAndScore() async throws {
        let profiles = [
            PlayerProfile(name: "Kind"),
            PlayerProfile.computer
        ]
        let engine = GameEngine(mode: .versusComputer, profiles: profiles, seed: 42)

        XCTAssertTrue(engine.canRoll)
        await engine.rollDice()
        XCTAssertTrue(engine.hasRolledThisTurn)
        XCTAssertEqual(engine.rollsRemaining, 2)
        XCTAssertTrue(engine.canScore)

        let open = YahtzeeScorer.availableCategories(
            dice: engine.diceValues,
            scorecard: engine.currentPlayer.scorecard
        )
        let category = try XCTUnwrap(open.first)
        engine.score(in: category)
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertTrue(engine.currentPlayer.isComputer)
    }
}
