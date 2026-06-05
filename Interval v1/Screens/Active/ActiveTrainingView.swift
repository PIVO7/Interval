import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @State private var engine: TimerEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showStopAlert = false
    @State private var showSaveSheet = false
    @State private var showAdjustSheet = false
    @State private var savedTrigger = 0
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

    init(workout: Workout, cues: CueOrchestrating) {
        _engine = State(wrappedValue: TimerEngine(workout: workout, cues: cues))
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
                FinishedView(
                    workout: engine.workout,
                    onHome: { dismiss() },
                    onRestart: { engine.restart() }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: phaseKey)
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            // Cancel the tick Task on any dismissal path — back-nav,
            // programmatic dismiss, memory pressure — so the engine
            // doesn't keep ticking after the view is gone. stop() is
            // idempotent, so the double call from the explicit Stop button
            // is harmless.
            engine.stop()
        }
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
            SaveFavoriteSheet(workout: engine.workout, onSave: saveFavorite)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAdjustSheet) {
            AdjustWorkoutSheet(engine: engine)
        }
        .sensoryFeedback(.success, trigger: savedTrigger)
        .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncErrorMessage ?? "")
        }
    }

    // MARK: - Persistence
    /// Persist the (possibly mid-workout-adjusted) workout as a favorite,
    /// then sync it to Supabase. Mirrors `FinishedView.saveFavorite` —
    /// guest mode / unconfigured backends are not surfaced as errors.
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

    // MARK: - Active layout
    private var activeContent: some View {
        VStack(spacing: 0) {
            roundIndicator
            Spacer()
            timerRing
            Spacer()
            phaseLabel
            Spacer()
            VStack(spacing: 18) {
                adjustPill
                controlButtons
            }
            .animation(.snappy(duration: 0.32, extraBounce: 0.02), value: engine.canAdjust)
            .padding(.bottom, 48)
        }
        .padding(.top, 52)
    }

    /// Subtle "Aanpassen" pill that fades in only when the engine accepts
    /// edits (paused, mid-workout). Keeps the primary control row tidy
    /// during active phases while signalling discoverability the moment
    /// the user pauses.
    @ViewBuilder
    private var adjustPill: some View {
        if engine.canAdjust {
            Button {
                showAdjustSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(.subheadline, weight: .semibold))
                    Text("Workout aanpassen")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.18))
                )
            }
            .transition(
                .opacity.combined(with: .move(edge: .bottom))
            )
            .accessibilityLabel(Text("Workout aanpassen"))
        }
    }

    private var roundIndicator: some View {
        VStack(spacing: 10) {
            Text("Ronde \(engine.currentRound) / \(engine.workout.rounds)")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            roundProgressIndicator
        }
        .padding(.top, 8)
        .animation(.snappy(duration: 0.3), value: engine.currentRound)
    }

    /// Visual round progress: dots for ≤12 rounds (most common Tabata/HIIT
    /// workouts), a progress bar above that to avoid clutter.
    @ViewBuilder
    private var roundProgressIndicator: some View {
        let total = engine.workout.rounds
        if total <= 12 {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { round in
                    Circle()
                        .fill(round <= engine.currentRound
                              ? Color.white
                              : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        } else {
            ProgressView(value: Double(engine.currentRound),
                         total: Double(total))
                .progressViewStyle(.linear)
                .tint(.white)
                .frame(width: 180)
        }
    }

    // Visual sizing for the timer ring + countdown text, scaled relative to
    // Dynamic Type so users with accessibility text sizes see a proportionally
    // larger hero element. Base values fit within iPhone SE's 375pt width.
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 340
    @ScaledMetric(relativeTo: .largeTitle) private var ringStroke: CGFloat = 22
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 108

    // Control button dimensions also scale with Dynamic Type so they stay
    // proportional to the ring/text on accessibility sizes and don't dwarf
    // the hero on iPad landscape with default sizing.
    @ScaledMetric(relativeTo: .body) private var primaryButtonSize: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var secondaryButtonSize: CGFloat = 52

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: ringStroke)
                .frame(width: ringSize, height: ringSize)
            // Progress — driven by wall clock via TimelineView so the ring
            // stays exactly in sync with the underlying timer (closes fully
            // at phase end, snaps cleanly to full at phase start).
            TimelineView(.animation) { context in
                Circle()
                    .trim(from: 0, to: engine.progress(at: context.date))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
            }

            // Timer text
            VStack(spacing: 6) {
                Text(
                    Duration.seconds(engine.secondsLeft),
                    format: .time(pattern: .minuteSecond)
                )
                .font(.system(size: timeFontSize, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.3), value: engine.secondsLeft)
            }
            .frame(maxWidth: ringSize - ringStroke * 2)
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

    // MARK: - Control buttons
    private var controlButtons: some View {
        HStack(alignment: .bottom, spacing: 28) {
            controlItem(
                icon: "xmark", size: secondaryButtonSize, bgOpacity: 0.18,
                label: "Stop",
                accessibility: Text("Stop training")
            ) { showStopAlert = true }

            controlItem(
                icon: engine.isPaused ? "play.fill" : "pause.fill",
                size: primaryButtonSize, bgOpacity: 0.28,
                label: engine.isPaused ? "Hervat" : "Pauze",
                accessibility: engine.isPaused ? Text("Hervatten") : Text("Pauzeren")
            ) { engine.togglePause() }

            controlItem(
                icon: "forward.end.fill", size: secondaryButtonSize, bgOpacity: 0.18,
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
        case .countdown: "countdown"
        case .work: "work"
        case .rest: "rest"
        case .finished: "finished"
        }
    }
}
