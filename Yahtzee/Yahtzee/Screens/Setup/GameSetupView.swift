import SwiftUI

struct GameSetupView: View {
    let mode: GameMode
    @Environment(ProfileStore.self) private var profileStore
    @State private var selectedIDs: Set<UUID> = []
    @State private var activeGame: ActiveGame?

    var body: some View {
        ZStack {
            AppTheme.felt.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(mode.title)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.cream)

                Text(mode.subtitle)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.cream.opacity(0.85))

                if profileStore.humanProfiles.isEmpty {
                    ContentUnavailableView(
                        "Geen profielen",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Maak eerst een profiel aan onder Profielen.")
                    )
                    .foregroundStyle(AppTheme.cream)
                } else {
                    Text(mode == .versusComputer ? "Kies jouw profiel" : "Kies 2 tot 4 spelers")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.gold)

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(profileStore.humanProfiles) { profile in
                                Button {
                                    toggle(profile.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        AvatarBadge(profile: profile)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(profile.name)
                                                .font(AppTheme.headlineFont)
                                                .foregroundStyle(AppTheme.ink)
                                            Text("\(profile.wins) overwinningen")
                                                .font(AppTheme.captionFont)
                                                .foregroundStyle(AppTheme.ink.opacity(0.6))
                                        }
                                        Spacer()
                                        Image(systemName: selectedIDs.contains(profile.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIDs.contains(profile.id) ? AppTheme.coral : AppTheme.ink.opacity(0.3))
                                            .font(.title2)
                                    }
                                    .padding(14)
                                    .background(AppTheme.cream.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        startGame()
                    } label: {
                        Text("Start spel")
                            .font(AppTheme.headlineFont)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canStart ? AppTheme.coral : AppTheme.coral.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .disabled(!canStart)
                }
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeGame) { game in
            GameView(engine: game.engine) {
                activeGame = nil
            }
            .environment(profileStore)
        }
    }

    private var canStart: Bool {
        switch mode {
        case .versusComputer:
            return selectedIDs.count == 1
        case .versusFriends:
            return (2...4).contains(selectedIDs.count)
        }
    }

    private func toggle(_ id: UUID) {
        if mode == .versusComputer {
            selectedIDs = [id]
            return
        }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < 4 {
            selectedIDs.insert(id)
        }
    }

    private func startGame() {
        let humans = profileStore.humanProfiles.filter { selectedIDs.contains($0.id) }
        var profiles = humans
        if mode == .versusComputer {
            profiles.append(.computer)
        }
        let engine = GameEngine(mode: mode, profiles: profiles)
        activeGame = ActiveGame(engine: engine)
    }
}

private struct ActiveGame: Identifiable {
    let id = UUID()
    let engine: GameEngine
}
