import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(ActiveSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var showSaveSheet = false
    @State private var showPaywall = false
    @State private var continueToSaveAfterUnlock = false
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
                // Content fits on tall devices — only allow scrolling when
                // it actually overflows (small screens, large Dynamic Type).
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("Roundly")
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
            .sensoryFeedback(.success, trigger: savedTrigger)
            // Single-button "OK" alert — SwiftUI provides the default OK
            // when no actions are declared (navigation.md guidance).
            .alert("Opslaan mislukt", isPresented: $showSyncErrorAlert) {
            } message: {
                Text(syncErrorMessage ?? "")
            }
            .onAppear(perform: triggerFirstLaunchNudgeIfNeeded)
        }
    }

    private func startTraining() {
        session.start(store.current, cues: cueOrchestrator)
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

    /// Persist the current workout as a favorite and flash the
    /// "Opgeslagen" confirmation. iCloud sync happens in the background.
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

    // MARK: - Summary card (hero)
    private var summaryCard: some View {
        HStack(spacing: 18) {
            BrandIconCircle {
                Image(systemName: "stopwatch.fill")
                    .font(.title2)
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
    // iOS 26+: Liquid Glass — merk-gradient onder helder glas voor de
    // primaire CTA, plain "Glass" voor de secundaire. Older systems keep
    // the original gradient capsule.
    private var actionButtons: some View {
        VStack(spacing: 14) {
            if #available(iOS 26.0, *) {
                // Zelfde oranje als de hero-medaillon bovenaan: de
                // coral→amber `buttonGradient` onder `.clear` glas (à la
                // BrandIconCircle) i.p.v. een getinte glassProminent, die
                // het oranje naar dof baksteen frostte.
                Button(action: startTraining) {
                    startLabel
                        .foregroundStyle(.white)
                        .padding(.vertical, 15)
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .background(Capsule().fill(AppTheme.buttonGradient))
                }
                .buttonStyle(PressableButtonStyle())
                // Full width on iPhone, but not a bar across the whole
                // column on iPad.
                .frame(maxWidth: 440)

                Button {
                    requestSaveFavorite()
                } label: {
                    saveLabel
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(AppTheme.coralText)
                .disabled(justSaved)
                .animation(.appSmooth, value: justSaved)
            } else {
                Button(action: startTraining) {
                    startLabel
                        .padding(.vertical, 15)
                        .background(AppTheme.buttonGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.coralDeep.opacity(0.35), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                // Full width on iPhone, but not a bar across the whole
                // column on iPad.
                .frame(maxWidth: 440)

                Button {
                    requestSaveFavorite()
                } label: {
                    saveLabel
                        .foregroundStyle(AppTheme.coralText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .disabled(justSaved)
                .animation(.appSmooth, value: justSaved)
            }
        }
        .padding(.top, 6)
    }

    private var startLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
            Text("Training starten")
        }
        .font(.system(.headline, design: .rounded, weight: .bold))
        .frame(maxWidth: .infinity)
    }

    private var saveLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: justSaved ? "checkmark.circle.fill" : "heart")
            Text(justSaved ? "Opgeslagen" : "Opslaan als favoriet")
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
    }
}

#Preview {
    HomeView()
        .environment(WorkoutStore())
        .environment(AudioSettings())
        .environment(StoreManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
