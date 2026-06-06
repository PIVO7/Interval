import SwiftUI
import SwiftData

struct FinishedView: View {
    let workout: Workout
    let onHome: () -> Void
    let onRestart: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(StoreManager.self) private var pro
    @Query private var favorites: [WorkoutEntity]
    @State private var showSaveSheet = false
    @State private var showPaywall = false
    @State private var continueToSaveAfterUnlock = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    // Staggered entrance — each element pops in shortly after the previous.
    @State private var trophyAppear = false
    @State private var titleAppear = false
    @State private var statsAppear = false
    @State private var buttonsAppear = false

    /// Hero "Goed gedaan!" headline size scales with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 36

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
            // Respect Reduce Motion: skip the big scale pop but still fade in.
            .scaleEffect(reduceMotion ? 1 : (trophyAppear ? 1 : 0.3))
            .opacity(trophyAppear ? 1 : 0)

            VStack(spacing: 10) {
                // Split emoji from text and re-label so VoiceOver doesn't
                // read it as "party popper" mid-sentence.
                Text("Goed gedaan! 🎉")
                    .font(.system(size: heroSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityLabel(Text("Goed gedaan"))
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
                    value: workout.workSeconds.asCompactDuration
                )
                divider
                statItem(
                    label: "Totaal",
                    value: workout.totalSeconds.asCompactDuration
                )
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .opacity(statsAppear ? 1 : 0)
            .offset(y: statsAppear ? 0 : 12)

            Spacer()

            // Buttons — "Nogmaals" is the primary action because users
            // who just finished a HIIT block often want another set right
            // away (Apple Fitness+ / Nike Training Club pattern). "Terug
            // naar home" demotes to a tertiary text link.
            VStack(spacing: 14) {
                if !alreadySaved {
                    Button {
                        requestSaveFavorite()
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

                Button(action: onRestart) {
                    Label("Herhaal", systemImage: "arrow.clockwise")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(AppTheme.coral)
                        .clipShape(Capsule())
                }

                Button(action: onHome) {
                    Text("Terug naar home")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("Terug naar home")
            }
            .padding(.bottom, 48)
            .opacity(buttonsAppear ? 1 : 0)
            .offset(y: buttonsAppear ? 0 : 14)
        }
        // Cap content width on iPad so the stats card and action buttons
        // don't stretch awkwardly to 1024pt. Matches the pattern used by
        // OnboardingView. Inner views still use maxWidth: .infinity within
        // this 560pt container, so iPhone layout is unchanged.
        .padding(.horizontal, 32)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.appBounce.delay(0.05)) { trophyAppear = true }
            withAnimation(.appSmooth.delay(0.25)) { titleAppear = true }
            withAnimation(.appSmooth.delay(0.4)) { statsAppear = true }
            withAnimation(.appSmooth.delay(0.55)) { buttonsAppear = true }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveFavoriteSheet(workout: workout, onSave: saveFavorite)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if continueToSaveAfterUnlock {
                continueToSaveAfterUnlock = false
                showSaveSheet = true
            }
        }) {
            PaywallView { continueToSaveAfterUnlock = true }
        }
        .sensoryFeedback(.success, trigger: savedTrigger)
        .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncErrorMessage ?? "")
        }
    }

    /// Gate the save action behind the Pro paywall; continue to the save
    /// sheet once unlocked.
    private func requestSaveFavorite() {
        if pro.isUnlocked {
            showSaveSheet = true
        } else {
            showPaywall = true
        }
    }

    /// Persist this workout as a favorite, then sync it to Supabase.
    /// Guest mode / unconfigured backends are not surfaced as errors.
    private func saveFavorite(_ saved: Workout) {
        modelContext.insert(WorkoutEntity(from: saved))
        do {
            try modelContext.save()
        } catch {
            syncErrorMessage = error.localizedDescription
            showSyncErrorAlert = true
            return
        }
        savedTrigger &+= 1
        Task {
            do {
                try await SupabaseManager.shared.upsertWorkout(saved)
            } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
                // Guest mode or unconfigured — local save is enough.
            } catch {
                syncErrorMessage = error.localizedDescription
                showSyncErrorAlert = true
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 36)
    }

    private func statItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            // Belt-and-braces safety: even with the compact "1m 10s"
            // format, very long workouts ("1h 5m") need single-line +
            // scaling so the three columns stay aligned across phones.
            Text(verbatim: value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview {
    ZStack {
        LinearGradient(colors: [AppTheme.sageDeep, AppTheme.forestDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
        FinishedView(workout: .placeholder, onHome: {}, onRestart: {})
            .environment(StoreManager())
            .modelContainer(for: WorkoutEntity.self, inMemory: true)
    }
}
