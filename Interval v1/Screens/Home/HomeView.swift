import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(\.modelContext) private var modelContext

    @State private var showSaveSheet = false
    @State private var showActive = false
    @State private var expandedField: EditField?
    @State private var justSaved = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    // First-launch nudge — briefly pulses the first interval row's value chip so
    // new users see that values are tappable. Runs once, then never again.
    @AppStorage("hasSeenIntervalsNudge") private var hasSeenIntervalsNudge = false
    @State private var nudgeWork = false

    enum EditField: Hashable {
        case work, rest, rounds
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        summaryCard
                        intervalsList
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
                SaveFavoriteSheet(workout: store.current) { saved in
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
                    withAnimation(.appSmooth) { justSaved = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.appSmooth) { justSaved = false }
                    }
                }
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showActive) {
                ActiveTrainingView(workout: store.current, audioSettings: audioSettings)
                    .environment(store)
                    .environment(audioSettings)
            }
            .sensoryFeedback(.success, trigger: savedTrigger)
            .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
                Button("OK", role: .cancel) {}
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
                Text(
                    Duration.seconds(store.current.totalSeconds),
                    format: .units(allowed: [.minutes, .seconds], width: .narrow)
                )
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                Text(verbatim: store.current.summary)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .padding(22)
        .softCard()
    }

    // MARK: - Intervals list (Calendar-style accordion in one card)
    private var intervalsList: some View {
        // `@Bindable` projects the @Observable store into a Binding context so
        // we can pass `$store.current.workSeconds` etc. into the wheel pickers.
        @Bindable var store = store
        return VStack(spacing: 0) {
            ValuePickerRow(
                title: "Work",
                systemImage: "flame.fill",
                tint: AppTheme.coral,
                value: formatTime(store.current.workSeconds),
                isSelected: expandedField == .work,
                isNudging: nudgeWork
            ) { toggle(.work) }

            if expandedField == .work {
                InlineTimeWheel(
                    seconds: $store.current.workSeconds,
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
                value: formatTime(store.current.restSeconds),
                isSelected: expandedField == .rest
            ) { toggle(.rest) }

            if expandedField == .rest {
                InlineTimeWheel(
                    seconds: $store.current.restSeconds,
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
                value: "\(store.current.rounds)",
                isSelected: expandedField == .rounds
            ) { toggle(.rounds) }

            if expandedField == .rounds {
                InlineRoundsWheel(rounds: $store.current.rounds)
                    .transition(.accordion)
            }
        }
        .softCard()
        // Snappier than `.appSmooth`: ~0.32s settle, almost no overshoot.
        // Tuned so the chip background, row tint, and wheel all finish
        // together for a single coordinated feel.
        .animation(.snappy(duration: 0.32, extraBounce: 0.02), value: expandedField)
    }

    private func toggle(_ field: EditField) {
        expandedField = (expandedField == field) ? nil : field
    }

    private func formatTime(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
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
                showSaveSheet = true
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
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
