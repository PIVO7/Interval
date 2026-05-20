import SwiftUI
import SwiftData

/// Bottom sheet for editing a saved favorite *in place*.
///
/// Reads initial values from the passed `WorkoutEntity` into local `@State` so
/// the user can Cancel without leaving the entity mutated. On Save, the
/// entity's properties are updated directly — SwiftData auto-persists. The
/// optional `onSave` callback fires after the mutation so the parent can
/// push the updated workout to Supabase.
struct EditFavoriteSheet: View {
    let entity: WorkoutEntity
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var rounds: Int
    @State private var expandedField: EditField?

    private enum EditField { case work, rest, rounds }

    init(entity: WorkoutEntity, onSave: @escaping () -> Void = {}) {
        self.entity = entity
        self.onSave = onSave
        self._name = State(initialValue: entity.name)
        self._workSeconds = State(initialValue: entity.workSeconds)
        self._restSeconds = State(initialValue: entity.restSeconds)
        self._rounds = State(initialValue: entity.rounds)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        nameField
                        intervalsList
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Favoriet bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar", action: save)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { entity.name = trimmed }
        entity.workSeconds = workSeconds
        entity.restSeconds = restSeconds
        entity.rounds = rounds
        onSave()
        dismiss()
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Naam")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
            TextField("Naam", text: $name)
                .font(.system(.title3, design: .rounded, weight: .medium))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.card)
                )
        }
    }

    // MARK: - Intervals accordion (same UX as HomeView)

    private var intervalsList: some View {
        VStack(spacing: 0) {
            ValuePickerRow(
                title: "Work",
                systemImage: "flame.fill",
                tint: AppTheme.coral,
                value: formatTime(workSeconds),
                isSelected: expandedField == .work
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
                value: formatTime(restSeconds),
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
                value: "\(rounds)",
                isSelected: expandedField == .rounds
            ) { toggle(.rounds) }

            if expandedField == .rounds {
                InlineRoundsWheel(rounds: $rounds)
                    .transition(.accordion)
            }
        }
        .softCard()
        .animation(.snappy(duration: 0.32, extraBounce: 0.02), value: expandedField)
    }

    private func toggle(_ field: EditField) {
        expandedField = (expandedField == field) ? nil : field
    }

    private func formatTime(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
