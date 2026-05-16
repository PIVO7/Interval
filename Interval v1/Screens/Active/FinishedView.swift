import SwiftUI
import SwiftData

struct FinishedView: View {
    let workout: Workout
    let onHome: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [WorkoutEntity]
    @State private var showSaveSheet = false
    @State private var appear = false

    private var alreadySaved: Bool {
        favorites.contains { $0.workSeconds == workout.workSeconds
            && $0.restSeconds == workout.restSeconds
            && $0.rounds == workout.rounds }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            // Trophy icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appear ? 1 : 0.3)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Goed gedaan! 🎉")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Training voltooid")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .opacity(appear ? 1 : 0)

            // Stats card
            HStack(spacing: 32) {
                statItem(label: "Ronden", value: "\(workout.rounds)")
                divider
                statItem(label: "Work", value: formatted(workout.workSeconds))
                divider
                statItem(label: "Totaal", value: formattedTotal)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
            .opacity(appear ? 1 : 0)

            Spacer()

            // Buttons
            VStack(spacing: 14) {
                if !alreadySaved {
                    Button {
                        showSaveSheet = true
                    } label: {
                        Label("Opslaan als favoriet", systemImage: "heart.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.22))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                Button(action: onHome) {
                    Text("Terug naar home")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(AppTheme.coral)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
                appear = true
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveFavoriteSheet(workout: workout) { saved in
                modelContext.insert(WorkoutEntity(from: saved))
                Task { try? await SupabaseManager.shared.upsertWorkout(saved) }
            }
            .presentationDetents([.medium])
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 36)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func formatted(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60; let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m\(s)s"
    }

    private var formattedTotal: String {
        let total = workout.rounds * workout.workSeconds
            + max(0, workout.rounds - 1) * workout.restSeconds
        let m = total / 60; let s = total % 60
        if m == 0 { return "\(s)s" }
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [AppTheme.sage, AppTheme.cream],
                       startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        FinishedView(workout: .placeholder, onHome: {})
            .modelContainer(for: WorkoutEntity.self, inMemory: true)
    }
}
