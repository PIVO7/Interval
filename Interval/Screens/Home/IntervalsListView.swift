import SwiftUI

/// Calendar-style accordion of the three workout parameters (work / rest /
/// rounds). Each row reveals an inline wheel picker on tap; only one row is
/// expanded at a time so the screen never grows out of control.
///
/// Reusable across every surface that edits a workout — the Home screen, the
/// "edit favorite" sheet, and the live "adjust" sheet — by taking plain
/// `Binding<Int>`s rather than a concrete model. Callers route those bindings
/// wherever they need (a `WorkoutStore`, local draft `@State`, or a
/// `TimerEngine`'s validated setters). `expandedField` is a `@Binding` so the
/// owner can collapse it from outside; `nudgeWork` drives the first-launch
/// "values are tappable" pulse on the Home screen.
struct IntervalsListView: View {
    @Binding var workSeconds: Int
    @Binding var restSeconds: Int
    @Binding var rounds: Int
    @Binding var expandedField: Field?
    var nudgeWork: Bool = false

    enum Field: Hashable { case work, rest, rounds }

    var body: some View {
        VStack(spacing: 0) {
            ValuePickerRow(
                title: "Work",
                systemImage: "flame.fill",
                tint: AppTheme.coral,
                value: workSeconds.asMinuteSecond,
                isSelected: expandedField == .work,
                isNudging: nudgeWork
            ) { toggle(.work) }

            if expandedField == .work {
                InlineTimeWheel(
                    seconds: $workSeconds,
                    minSeconds: 5,
                    maxSeconds: 3600
                )
                .transition(.accordion)
            }

            Divider().padding(.leading, 68)

            ValuePickerRow(
                title: "Rest",
                systemImage: "leaf.fill",
                tint: AppTheme.sage,
                value: restSeconds.asMinuteSecond,
                isSelected: expandedField == .rest
            ) { toggle(.rest) }

            if expandedField == .rest {
                InlineTimeWheel(
                    seconds: $restSeconds,
                    minSeconds: 0,
                    maxSeconds: 3600
                )
                .transition(.accordion)
            }

            Divider().padding(.leading, 68)

            ValuePickerRow(
                title: "Rounds",
                systemImage: "repeat",
                tint: AppTheme.amber,
                value: rounds.formatted(),
                isSelected: expandedField == .rounds
            ) { toggle(.rounds) }

            if expandedField == .rounds {
                InlineRoundsWheel(rounds: $rounds)
                    .transition(.accordion)
            }
        }
        .softCard()
        // Snappier than `.appSmooth`: ~0.32s settle, almost no overshoot.
        // Tuned so the chip background, row tint, and wheel all finish
        // together for a single coordinated feel.
        .animation(.snappy(duration: 0.32, extraBounce: 0.02), value: expandedField)
    }

    private func toggle(_ field: Field) {
        expandedField = (expandedField == field) ? nil : field
    }
}
