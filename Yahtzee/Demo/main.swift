// Headless "hello world" demo for the Yahtzee core.
//
// Drives the SAME game engine, scorer, AI and profile store the iOS app uses,
// but with no UI — so the core game logic can be exercised end-to-end on Linux.
// Run with:  swift run YahtzeeDemo
//
// Uses @testable import because the core types have module-internal access (the
// unit tests reach them the same way). This is a dev/CI harness only.

import Foundation
@testable import Yahtzee

@main
struct YahtzeeDemo {
    @MainActor
    static func main() async {
        print("=== Yahtzee core demo (headless) ===\n")

        // 1) Profiles persisted to JSON (same store the app uses).
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("yahtzee-demo-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let store = ProfileStore(fileURL: storeURL)
        store.addProfile(name: "Mila")
        let mila = store.humanProfiles.first!
        print("Created profile: \(mila.name) (wins: \(mila.wins), games: \(mila.gamesPlayed))")

        // 2) Play a full game: human (Mila) vs the computer AI. Fixed seed => reproducible.
        let profiles = [mila, PlayerProfile.computer]
        let engine = GameEngine(mode: .versusComputer, profiles: profiles, seed: 2026)
        print("Starting game: \(profiles.map(\.name).joined(separator: " vs ")) (seed 2026)\n")

        var turn = 0
        while !engine.isFinished {
            if engine.currentPlayer.isComputer {
                await engine.playComputerTurnIfNeeded()
                continue
            }

            turn += 1
            // Human strategy: roll, hold nothing, use remaining rolls, then take the
            // highest-scoring open category.
            while engine.canRoll {
                await engine.rollDice()
            }
            let open = YahtzeeScorer.availableCategories(
                dice: engine.diceValues,
                scorecard: engine.currentPlayer.scorecard
            )
            guard let pick = open.max(by: { lhs, rhs in
                let l = YahtzeeScorer.pointsForPlacing(category: lhs, dice: engine.diceValues, scorecard: engine.currentPlayer.scorecard)
                let r = YahtzeeScorer.pointsForPlacing(category: rhs, dice: engine.diceValues, scorecard: engine.currentPlayer.scorecard)
                return (l.score + l.yahtzeeBonus) < (r.score + r.yahtzeeBonus)
            }) else { break }

            let result = YahtzeeScorer.pointsForPlacing(
                category: pick, dice: engine.diceValues, scorecard: engine.currentPlayer.scorecard
            )
            print(String(format: "Turn %2d  %-8@ dice %@ -> %@ (%d pts)",
                         turn, engine.currentPlayer.name as NSString,
                         engine.diceValues.map(String.init).joined(separator: ",") as NSString,
                         pick.title as NSString, result.score + result.yahtzeeBonus))
            engine.score(in: pick)
        }

        // 3) Final result.
        print("\n--- Final scorecards ---")
        for player in engine.players {
            print(String(format: "%-10@ total: %d (upper %d + bonus %d, lower %d, yahtzee-bonus %d)",
                         player.name as NSString, player.scorecard.total,
                         player.scorecard.upperSubtotal, player.scorecard.upperBonus,
                         player.scorecard.lowerSubtotal, player.scorecard.yahtzeeBonusTotal))
        }
        print("\n" + engine.turnMessage)

        // 4) Record the result back into the persistent store.
        store.recordGameResult(
            winnerProfileIDs: engine.winnerProfileIDs,
            participantProfileIDs: engine.players.map(\.profileID)
        )
        let updated = store.humanProfiles.first(where: { $0.id == mila.id })!
        print("\nProfile after game: \(updated.name) -> wins: \(updated.wins), games: \(updated.gamesPlayed)")

        // 5) Prove persistence: reload from disk.
        let reloaded = ProfileStore(fileURL: storeURL)
        let persisted = reloaded.humanProfiles.first(where: { $0.id == mila.id })!
        print("Reloaded from disk: \(persisted.name) -> wins: \(persisted.wins), games: \(persisted.gamesPlayed)")

        print("\n=== Demo complete ===")
    }
}
