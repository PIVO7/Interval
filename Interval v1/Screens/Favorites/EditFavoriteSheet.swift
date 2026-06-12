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
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var workSeconds: Int
    @State private var restSeconds: Int
    @State private var rounds: Int
    @State private var expandedField: IntervalsListView.Field?

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
                        IntervalsListView(
                            workSeconds: $workSeconds,
                            restSeconds: $restSeconds,
                            rounds: $rounds,
                            expandedField: $expandedField
                        )
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
                        // Disable rather than silently dropping an empty
                        // rename — the previous behaviour kept the old
                        // name with no user feedback, which felt like a
                        // bug ("I typed and it didn't save").
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        // Bewaar button is disabled when trimmed is empty so this is safe.
        entity.name = trimmedName
        entity.workSeconds = workSeconds
        entity.restSeconds = restSeconds
        entity.rounds = rounds
        // Persist now rather than relying on autosave — onSave() pushes to
        // Supabase immediately, and remote-newer-than-local after a crash
        // would be a confusing state.
        try? modelContext.save()
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

}
