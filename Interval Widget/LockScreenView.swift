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
                        // Use the persisted phaseStartDate (canonical pattern)
                        // so this Text and the ProgressView below share the
                        // same interval baseline.
                        Text(timerInterval: state.phaseStartDate...state.phaseEndDate,
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
                    // Trophy state has less content than the timer state;
                    // center it vertically inside the card so it doesn't
                    // float at the top (visible on iPad's wider lock card).
                    Spacer(minLength: 0)
                    HStack {
                        Text("Training voltooid")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
        }
    }
}
