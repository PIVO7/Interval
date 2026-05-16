import SwiftUI

struct SaveFavoriteSheet: View {
    let workout: Workout
    var onSave: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Naam")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField(autoSuggestion, text: $name)
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.card)
                            )
                    }
                    Text(workout.summary)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button {
                        var saved = workout
                        saved.name = name.isEmpty ? autoSuggestion : name
                        onSave(saved)
                        dismiss()
                    } label: {
                        Text("Opslaan")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.workGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(24)
            }
            .navigationTitle("Favoriet opslaan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }

    private var autoSuggestion: String {
        String(format: NSLocalizedString("Tabata %lld/%lld",
                                         comment: "Auto-suggested favorite name (work seconds / rest seconds)"),
               workout.workSeconds,
               workout.restSeconds)
    }
}
