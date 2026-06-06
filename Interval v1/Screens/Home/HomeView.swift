import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(\.modelContext) private var modelContext

    @State private var showSaveSheet = false
    @State private var showPaywall = false
    @State private var continueToSaveAfterUnlock = false
    @State private var showActive = false
    @State private var expandedField: IntervalsListView.Field?
    @State private var justSaved = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    // First-launch nudge — briefly pulses the first interval row's value chip so
    // new users see that values are tappable. Runs once, then never again.
    @AppStorage("hasSeenIntervalsNudge") private var hasSeenIntervalsNudge = false
    @State private var nudgeWork = false

    var body: some View {
        @Bindable var store = store
        return NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        summaryCard
                        IntervalsListView(
                            workSeconds: $store.current.workSeconds,
                            restSeconds: $store.current.restSeconds,
                            rounds: $store.current.rounds,
                            expandedField: $expandedField,
                            nudgeWork: nudgeWork
                        )
                        actionButtons
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Interval")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSaveSheet) {
                SaveFavoriteSheet(workout: store.current, onSave: saveFavorite)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                // Continue to the save sheet only after the paywall has fully
                // dismissed, avoiding a present-while-dismissing race.
                if continueToSaveAfterUnlock {
                    continueToSaveAfterUnlock = false
                    showSaveSheet = true
                }
            }) {
                PaywallView { continueToSaveAfterUnlock = true }
            }
            .fullScreenCover(isPresented: $showActive) {
                ActiveTrainingView(workout: store.current, cues: cueOrchestrator)
                    .environment(store)
                    .environment(audioSettings)
                    .environment(pro)
            }
            .sensoryFeedback(.success, trigger: savedTrigger)
            // Single-button "OK" alert — SwiftUI provides the default OK
            // when no actions are declared (navigation.md guidance).
            .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
            } message: {
                Text(syncErrorMessage ?? "")
            }
            .onAppear(perform: triggerFirstLaunchNudgeIfNeeded)
            .onChange(of: store.pendingStart) { _, newValue in
                guard newValue != nil else { return }
                showActive = true
                store.pendingStart = nil
            }
        }
    }

    /// Entry point for the "Opslaan als favoriet" button. Saving named
    /// favorites is the Pro feature — gate behind the paywall, then continue
    /// to the save sheet once unlocked.
    private func requestSaveFavorite() {
        if pro.isUnlocked {
            showSaveSheet = true
        } else {
            showPaywall = true
        }
    }

    /// Persist the current workout as a favorite, sync it to Supabase, and
    /// flash the "Opgeslagen" confirmation. Guest mode / unconfigured
    /// backends are not surfaced as errors — the local save is enough.
    private func saveFavorite(_ saved: Workout) {
        modelContext.insert(WorkoutEntity(from: saved))
        // Force-persist now — SwiftData's autosave can lag, and showing
        // the success toast while the row isn't yet on disk risks losing
        // the save if the app dies.
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
        withAnimation(.appSmooth) { justSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.appSmooth) { justSaved = false }
        }
    }

    private func triggerFirstLaunchNudgeIfNeeded() {
        guard !hasSeenIntervalsNudge else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.appBounce) { nudgeWork = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.appSmooth) { nudgeWork = false }
            hasSeenIntervalsNudge = true
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Klaar voor je sessie")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Stel je intervallen in en begin wanneer je klaar bent.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Summary card (hero)
    private var summaryCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.workGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "stopwatch.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Totale duur")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(verbatim: store.current.totalSeconds.asCompactDuration)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // Summary subline removed — duplicated the work/rest/rounds
                // info that already lives in the IntervalsListView right
                // below this card, and the middle-dot separators read
                // visually noisy at small footnote size.
            }
            Spacer()
        }
        .padding(22)
        .softCard()
    }

    // MARK: - Action buttons
    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Primary: start the training
            Button {
                showActive = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start training")
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.workGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: AppTheme.coral.opacity(0.45), radius: 10, x: 0, y: 6)
            }
            .accessibilityLabel("Start training")

            // Secondary: subtle text-only save action
            Button {
                requestSaveFavorite()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: justSaved ? "checkmark.circle.fill" : "heart")
                    Text(justSaved ? "Opgeslagen" : "Opslaan als favoriet")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Opslaan als favoriet")
            .disabled(justSaved)
            .animation(.appSmooth, value: justSaved)
        }
        .padding(.top, 6)
    }
}

#Preview {
    HomeView()
        .environment(WorkoutStore())
        .environment(AudioSettings())
        .environment(StoreManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
