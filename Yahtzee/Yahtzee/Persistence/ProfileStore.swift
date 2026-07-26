import Foundation
import Observation

@Observable
final class ProfileStore {
    private(set) var profiles: [PlayerProfile] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "yahtzee-profiles.json") {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = folder.appendingPathComponent(filename)
        load()
    }

    /// Test seam.
    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    var humanProfiles: [PlayerProfile] {
        profiles.filter { !$0.isComputer }.sorted { $0.createdAt < $1.createdAt }
    }

    func addProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let color = profiles.count % 6
        let profile = PlayerProfile(name: trimmed, avatarColorIndex: color)
        profiles.append(profile)
        save()
    }

    func renameProfile(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = profiles.firstIndex(where: { $0.id == id && !$0.isComputer }) else { return }
        profiles[index].name = trimmed
        save()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id && !$0.isComputer }
        save()
    }

    func recordGameResult(winnerProfileIDs: [UUID], participantProfileIDs: [UUID]) {
        for id in participantProfileIDs where id != PlayerProfile.computerID {
            guard let index = profiles.firstIndex(where: { $0.id == id }) else { continue }
            profiles[index].gamesPlayed += 1
            if winnerProfileIDs.contains(id), winnerProfileIDs.count == 1 {
                profiles[index].wins += 1
            }
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            profiles = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            profiles = try decoder.decode([PlayerProfile].self, from: data)
                .filter { !$0.isComputer }
        } catch {
            profiles = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(profiles.filter { !$0.isComputer })
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Local-only kids app; ignore disk errors silently.
        }
    }
}
