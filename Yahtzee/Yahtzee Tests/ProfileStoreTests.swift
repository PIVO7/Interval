import XCTest
@testable import Yahtzee

final class ProfileStoreTests: XCTestCase {
    func testAddAndRecordWins() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yahtzee-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProfileStore(fileURL: url)
        store.addProfile(name: "Mila")
        store.addProfile(name: "Noah")

        let mila = try XCTUnwrap(store.humanProfiles.first(where: { $0.name == "Mila" }))
        let noah = try XCTUnwrap(store.humanProfiles.first(where: { $0.name == "Noah" }))

        store.recordGameResult(
            winnerProfileIDs: [mila.id],
            participantProfileIDs: [mila.id, noah.id]
        )

        let updatedMila = try XCTUnwrap(store.humanProfiles.first(where: { $0.id == mila.id }))
        let updatedNoah = try XCTUnwrap(store.humanProfiles.first(where: { $0.id == noah.id }))
        XCTAssertEqual(updatedMila.wins, 1)
        XCTAssertEqual(updatedMila.gamesPlayed, 1)
        XCTAssertEqual(updatedNoah.wins, 0)
        XCTAssertEqual(updatedNoah.gamesPlayed, 1)

        let reloaded = ProfileStore(fileURL: url)
        XCTAssertEqual(reloaded.humanProfiles.count, 2)
        XCTAssertEqual(reloaded.humanProfiles.first(where: { $0.id == mila.id })?.wins, 1)
    }

    func testTieDoesNotAwardWin() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("yahtzee-tie-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProfileStore(fileURL: url)
        store.addProfile(name: "A")
        store.addProfile(name: "B")
        let ids = store.humanProfiles.map(\.id)

        store.recordGameResult(winnerProfileIDs: ids, participantProfileIDs: ids)
        XCTAssertTrue(store.humanProfiles.allSatisfy { $0.wins == 0 })
        XCTAssertTrue(store.humanProfiles.allSatisfy { $0.gamesPlayed == 1 })
    }
}
