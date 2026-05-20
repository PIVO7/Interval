import ActivityKit
import SwiftUI

struct LockScreenView: View {
    let state: IntervalActivityAttributes.ContentState
    let attributes: IntervalActivityAttributes

    var body: some View {
        ZStack {
            state.phase.gradient

            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: state.phase.symbol)
                        Text(state.phase.label)
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .tracking(2)
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    if state.phase != .finished {
                        Text(verbatim: "Ronde \(state.currentRound) / \(attributes.totalRounds)")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                if state.phase != .finished {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(timerInterval: Date.now...state.phaseEndDate,
                             countsDown: true,
                             showsHours: false)
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)

                        Spacer()

                        Text(verbatim: attributes.workoutName)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    ProgressView(timerInterval: state.phaseStartDate...state.phaseEndDate,
                                 countsDown: true)
                        .tint(.white)
                } else {
                    HStack {
                        Text("Training voltooid")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }
}
