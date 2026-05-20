import SwiftUI
import SwiftData

struct FinishedView: View {
    let workout: Workout
    let onHome: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [WorkoutEntity]
    @State private var showSaveSheet = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    // Staggered entrance — each element pops in shortly after the previous.
    @State private var trophyAppear = false
    @State private var titleAppear = false
    @State private var statsAppear = false
    @State private var buttonsAppear = false

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
            .scaleEffect(trophyAppear ? 1 : 0.3)
            .opacity(trophyAppear ? 1 : 0)

            VStack(spacing: 10) {
                Text("Goed gedaan! 🎉")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Training voltooid")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .opacity(titleAppear ? 1 : 0)
            .offset(y: titleAppear ? 0 : 10)

            // Stats card
            HStack(spacing: 32) {
                statItem(label: "Ronden", value: "\(workout.rounds)")
                divider
                statItem(
                    label: "Per ronde",
                    value: Duration.seconds(workout.workSeconds)
                        .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
                )
                divider
                statItem(
                    label: "Totaal",
                    value: Duration.seconds(totalSeconds)
                        .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
                )
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
            .opacity(statsAppear ? 1 : 0)
            .offset(y: statsAppear ? 0 : 12)

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
            .opacity(buttonsAppear ? 1 : 0)
            .offset(y: buttonsAppear ? 0 : 14)
        }
        .onAppear {
            withAnimation(.appBounce.delay(0.05)) { trophyAppear = true }
            withAnimation(.appSmooth.delay(0.25)) { titleAppear = true }
            withAnimation(.appSmooth.delay(0.4)) { statsAppear = true }
            withAnimation(.appSmooth.delay(0.55)) { buttonsAppear = true }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveFavoriteSheet(workout: workout) { saved in
                modelContext.insert(WorkoutEntity(from: saved))
                savedTrigger &+= 1
                Task {
                    do {
                        try await SupabaseManager.shared.upsertWorkout(saved)
                    } catch {
                        syncErrorMessage = error.localizedDescription
                        showSyncErrorAlert = true
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: savedTrigger)
        .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncErrorMessage ?? "")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 36)
    }

    private func statItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var totalSeconds: Int {
        workout.rounds * workout.workSeconds
            + max(0, workout.rounds - 1) * workout.restSeconds
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [AppTheme.sageDeep, AppTheme.forestDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
        FinishedView(workout: .placeholder, onHome: {})
            .modelContainer(for: WorkoutEntity.self, inMemory: true)
    }
}
