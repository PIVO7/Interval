import SwiftUI

/// Bottom sheet for fine-tuning the running workout (work/rest/rounds)
/// while it's paused. Mirrors the accordion-style picker UI from
/// `EditFavoriteSheet` for consistency, but writes through to the
/// `TimerEngine` directly so changes apply to the live session.
///
/// Edits are committed live (each wheel-tick updates the engine) — the
/// "Klaar" button just dismisses. There is no Cancel, because there is
/// no draft state: the user can dial values back manually if they
/// overshoot. This matches Apple's stopwatch/timer pattern.
struct AdjustWorkoutSheet: View {
    @Bindable var engine: TimerEngine

    @Environment(\.dismiss) private var dismiss

    @State private var expandedField: IntervalsListView.Field?

    /// Single fixed detent — the sheet is a "quick-tune" affordance, not
    /// a browsing surface. A resizable sheet invites dragging instead of
    /// editing, which is the opposite of what we want here. 520pt fits
    /// the 3 rows + one expanded wheel + nav bar comfortably on iPhone SE
    /// (the smallest supported device at 667pt).
    private static let sheetHeight: CGFloat = 520

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        IntervalsListView(
                            workSeconds: workBinding,
                            restSeconds: restBinding,
                            rounds: roundsBinding,
                            expandedField: $expandedField
                        )
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Aanpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(Self.sheetHeight)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Bindings that route through the engine's validated setters

    private var workBinding: Binding<Int> {
        Binding(
            get: { engine.workout.workSeconds },
            set: { engine.updateWorkSeconds($0) }
        )
    }

    private var restBinding: Binding<Int> {
        Binding(
            get: { engine.workout.restSeconds },
            set: { engine.updateRestSeconds($0) }
        )
    }

    private var roundsBinding: Binding<Int> {
        Binding(
            get: { engine.workout.rounds },
            set: { engine.updateRounds($0) }
        )
    }
}
