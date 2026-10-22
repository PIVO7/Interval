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
                    // iOS 26+: zelfde behandeling als de Home-CTA — de
                    // merk-gradient onder helder interactief glas. Older
                    // systems keep the gradient capsule.
                    if #available(iOS 26.0, *) {
                        Button(action: save) {
                            Text("Opslaan")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .padding(.vertical, 16)
                                .glassEffect(.clear.interactive(), in: .capsule)
                                .background(Capsule().fill(AppTheme.buttonGradient))
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        Button(action: save) {
                            Text("Opslaan")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.buttonGradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
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

    private func save() {
        var saved = workout
        // A save always creates a NEW favorite. The incoming workout may
        // carry the id of an existing favorite (started from FavoritesView,
        // or saved earlier from Home) — keeping it would leave two
        // favorites sharing one id. Fresh id + timestamp also keeps the
        // createdAt-sorted list honest.
        saved.id = UUID()
        saved.createdAt = .now
        // Trim whitespace so " " typed by accident doesn't produce a
        // blank-looking favorite. Falls back to the autosuggestion if the
        // user trimmed to empty.
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.name = trimmed.isEmpty ? autoSuggestion : trimmed
        onSave(saved)
        dismiss()
    }

    private var autoSuggestion: String {
        String(
            localized: "Tabata \(workout.workSeconds)/\(workout.restSeconds)",
            comment: "Auto-suggested favorite name (work seconds / rest seconds)"
        )
    }
}
