import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @State private var engine: TimerEngine
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showStopAlert = false
    @State private var showSaveSheet = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    init(workout: Workout, audioSettings: AudioSettings) {
        _engine = State(wrappedValue: TimerEngine(workout: workout, audioSettings: audioSettings))
    }

    var body: some View {
        ZStack {
            phaseBackground.ignoresSafeArea()
            switch engine.phase {
            case .countdown(let n):
                CountdownView(count: n)
                    .transition(.opacity.combined(with: .scale))
            case .work, .rest:
                activeContent
                    .transition(.opacity)
            case .finished:
                FinishedView(workout: engine.workout, onHome: { dismiss() })
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: phaseKey)
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { engine.recomputeFromWallClock() }
        }
        .alert("Training stoppen?", isPresented: $showStopAlert) {
            Button("Stoppen", role: .destructive) { engine.stop(); dismiss() }
            Button("Doorgaan", role: .cancel) {}
        } message: {
            Text("Je huidige voortgang gaat verloren.")
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveFavoriteSheet(workout: engine.workout) { saved in
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

    // MARK: - Active layout
    private var activeContent: some View {
        VStack(spacing: 0) {
            roundIndicator
            Spacer()
            timerRing
            Spacer()
            phaseLabel
            Spacer()
            ambientControl
                .padding(.bottom, 16)
            controlButtons
                .padding(.bottom, 48)
        }
        .padding(.top, 52)
    }

    private var roundIndicator: some View {
        Text("Ronde \(engine.currentRound) / \(engine.workout.rounds)")
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.top, 8)
    }

    // Visual sizing for the timer ring + countdown text, scaled relative to
    // Dynamic Type so users with accessibility text sizes see a proportionally
    // larger hero element. Base values tuned for the default size class:
    // ring stays inside iPhone SE's 320pt width with ~10pt breathing room.
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 320
    @ScaledMetric(relativeTo: .largeTitle) private var ringStroke: CGFloat = 22
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 96

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: ringStroke)
                .frame(width: ringSize, height: ringSize)
            // Progress
            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.progress)

            // Timer text
            VStack(spacing: 6) {
                Text(
                    Duration.seconds(engine.secondsLeft),
                    format: .time(pattern: .minuteSecond)
                )
                .font(.system(size: timeFontSize, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.3), value: engine.secondsLeft)
            }
        }
    }

    private var phaseLabel: some View {
        Group {
            if case .work = engine.phase {
                Text("WORK")
            } else {
                Text("REST")
            }
        }
        .font(.system(size: 34, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .tracking(4)
    }

    // MARK: - Ambient volume mini-control
    @ViewBuilder
    private var ambientControl: some View {
        if audioSettings.ambientSound == .none {
            EmptyView()
        } else {
            // `@Bindable` projects the @Observable audio settings into a Binding.
            @Bindable var audioSettings = audioSettings
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.white)
                    .font(.caption.weight(.semibold))
                Slider(value: $audioSettings.ambientVolume, in: 0...1)
                    .tint(.white)
                    .frame(maxWidth: 160)
                    .onChange(of: audioSettings.ambientVolume) { _, new in
                        engine.updateVolume(new)
                    }
                Text(audioSettings.ambientSound.displayName)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Control buttons
    private var controlButtons: some View {
        HStack(alignment: .bottom, spacing: 28) {
            controlItem(
                icon: "xmark", size: 52, bgOpacity: 0.18,
                label: "Stop",
                accessibility: Text("Stop training")
            ) { showStopAlert = true }

            controlItem(
                icon: engine.isPaused ? "play.fill" : "pause.fill",
                size: 72, bgOpacity: 0.28,
                label: engine.isPaused ? "Hervat" : "Pauze",
                accessibility: engine.isPaused ? Text("Hervatten") : Text("Pauzeren")
            ) { engine.togglePause() }

            controlItem(
                icon: "forward.end.fill", size: 52, bgOpacity: 0.18,
                label: "Skip",
                accessibility: Text("Volgende fase overslaan")
            ) { engine.skip() }
        }
    }

    private func controlItem(
        icon: String,
        size: CGFloat,
        bgOpacity: Double,
        label: LocalizedStringKey,
        accessibility: Text,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color.white.opacity(bgOpacity)))
            }
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }

    // MARK: - Helpers
    private var phaseBackground: LinearGradient {
        switch engine.phase {
        case .countdown, .work:
            return LinearGradient(
                colors: [AppTheme.coral, AppTheme.coralDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .rest:
            return LinearGradient(
                colors: [AppTheme.sage, AppTheme.sageDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .finished:
            return LinearGradient(
                colors: [AppTheme.sageDeep, AppTheme.forestDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var phaseKey: String {
        switch engine.phase {
        case .countdown: return "countdown"
        case .work: return "work"
        case .rest: return "rest"
        case .finished: return "finished"
        }
    }
}
