import SwiftUI

/// Mini-player-style strip in the tab bar accessory (iOS 26+) while a
/// training runs minimized: phase dot + countdown + round progress, plus a
/// pause/resume control. Tapping the strip reopens the fullscreen training.
@available(iOS 26.0, *)
struct ActiveSessionAccessory: View {
    let engine: TimerEngine
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(phaseColor)
                        .frame(width: 10, height: 10)
                    Text(
                        Duration.seconds(engine.secondsLeft),
                        format: .time(pattern: .minuteSecond)
                    )
                    .font(.system(.headline, design: .rounded, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.3), value: engine.secondsLeft)
                    Text("Ronde \(engine.currentRound) / \(engine.workout.rounds)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isFinished {
                Button {
                    engine.togglePause()
                } label: {
                    Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(.body, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.isPaused ? Text("Hervatten") : Text("Pauzeren"))
            }
        }
        .padding(.horizontal, 18)
    }

    private var isFinished: Bool {
        if case .finished = engine.phase { true } else { false }
    }

    private var phaseColor: Color {
        switch engine.phase {
        case .countdown: AppTheme.amber
        case .work: AppTheme.coral
        case .rest: AppTheme.sage
        case .finished: AppTheme.sageDeep
        }
    }
}
