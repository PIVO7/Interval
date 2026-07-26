import SwiftUI

struct GameView: View {
    @Bindable var engine: GameEngine
    @Environment(ProfileStore.self) private var profileStore
    let onClose: () -> Void

    @State private var didRecordResult = false
    @State private var showExitConfirm = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.felt, AppTheme.feltDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                playerStrip
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                DiceTrayView(
                    dice: engine.dice,
                    isRolling: engine.isRolling,
                    canInteract: engine.canScore && engine.rollsRemaining > 0
                ) { id in
                    engine.toggleHold(dieID: id)
                }
                .padding(.horizontal, 12)

                Text(engine.turnMessage)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.cream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                HStack(spacing: 12) {
                    Label("\(engine.rollsRemaining) worpen over", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.gold)

                    Spacer()

                    Button {
                        Task { await engine.rollDice() }
                    } label: {
                        Text(engine.isRolling ? "Bezig…" : "Gooien")
                            .font(AppTheme.headlineFont)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                engine.canRoll ? AppTheme.coral : AppTheme.coral.opacity(0.35),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                    }
                    .disabled(!engine.canRoll)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                ScorecardView(
                    players: engine.players,
                    currentPlayerID: engine.currentPlayer.id,
                    diceValues: engine.diceValues,
                    canScore: engine.canScore,
                    onSelect: { engine.score(in: $0) }
                )
            }

            if engine.isFinished {
                resultOverlay
            }
        }
        .task(id: engine.currentPlayerIndex) {
            await engine.playComputerTurnIfNeeded()
        }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished, !didRecordResult else { return }
            didRecordResult = true
            profileStore.recordGameResult(
                winnerProfileIDs: engine.winnerProfileIDs,
                participantProfileIDs: engine.players.map(\.profileID)
            )
        }
        .confirmationDialog("Spel verlaten?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Verlaten", role: .destructive, action: onClose)
            Button("Doorspelen", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button {
                if engine.isFinished {
                    onClose()
                } else {
                    showExitConfirm = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.cream.opacity(0.9))
            }
            Spacer()
            Text("Yahtzee")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.cream)
            Spacer()
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var playerStrip: some View {
        HStack(spacing: 8) {
            ForEach(engine.players) { player in
                VStack(spacing: 4) {
                    Text(player.name)
                        .font(AppTheme.captionFont)
                        .lineLimit(1)
                    Text("\(player.scorecard.total)")
                        .font(AppTheme.headlineFont)
                }
                .foregroundStyle(player.id == engine.currentPlayer.id ? AppTheme.ink : AppTheme.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    player.id == engine.currentPlayer.id ? AppTheme.gold : AppTheme.feltDeep.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Klaar!")
                    .font(AppTheme.titleFont)
                Text(engine.turnMessage)
                    .font(AppTheme.bodyFont)
                    .multilineTextAlignment(.center)

                ForEach(engine.players) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text("\(player.scorecard.total)")
                            .font(AppTheme.headlineFont)
                    }
                }

                Button("Terug naar menu", action: onClose)
                    .font(AppTheme.headlineFont)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.coral, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
            .foregroundStyle(AppTheme.ink)
            .padding(24)
            .background(AppTheme.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(28)
        }
        .transition(.opacity.combined(with: .scale))
    }
}
