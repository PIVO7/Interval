import SwiftUI
import SwiftData

/// Bottom sheet for editing a saved favorite *in place*.
///
/// Reads initial values from the passed `WorkoutEntity` into local `@State` so
/// the user can Cancel without leaving the entity mutated. On Save, the
/// entity's properties are updated directly and the edit is marked for
/// upload. The optional `onSave` callback fires after the save so the
/// parent can kick off a sync.
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
    @State private var showSaveError = false

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
        .alert("Opslaan mislukt", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Je wijzigingen konden niet worden bewaard. Probeer het opnieuw.")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        // Snapshot so a failed persist can roll the entity back — it's
        // already mutated below, and leaving it half-saved would show
        // edited values in the list that never reached disk.
        let original = (entity.name, entity.workSeconds, entity.restSeconds, entity.rounds,
                        entity.updatedAt, entity.needsUpload)
        // Bewaar button is disabled when trimmed is empty so this is safe.
        entity.name = trimmedName
        entity.workSeconds = workSeconds
        entity.restSeconds = restSeconds
        entity.rounds = rounds
        // Queue the edit for upload in the same save, so it survives a
        // failed or offline upload and wins over an older server copy.
        entity.markEdited()
        // Persist now rather than relying on autosave — onSave() starts a
        // sync immediately. Only sync once the local save stuck.
        do {
            try modelContext.save()
        } catch {
            (entity.name, entity.workSeconds, entity.restSeconds, entity.rounds,
             entity.updatedAt, entity.needsUpload) = original
            showSaveError = true
            return
        }
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
