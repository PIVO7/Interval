import SwiftUI

struct ActiveTrainingView: View {
    @StateObject private var engine: TimerEngine
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var showStopAlert = false
    @State private var showSaveSheet = false

    init(workout: Workout) {
        _engine = StateObject(wrappedValue: TimerEngine(workout: workout))
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
                    .environmentObject(store)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: phaseKey)
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert("Training stoppen?", isPresented: $showStopAlert) {
            Button("Stoppen", role: .destructive) { engine.stop(); dismiss() }
            Button("Doorgaan", role: .cancel) {}
        } message: {
            Text("Je huidige voortgang gaat verloren.")
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveFavoriteSheet(workout: engine.workout) { store.addFavorite($0) }
                .presentationDetents([.medium])
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
            controlButtons
                .padding(.bottom, 48)
        }
        .padding(.top, 52)
    }

    private var roundIndicator: some View {
        Text("Ronde \(engine.currentRound) / \(engine.workout.rounds)")
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.top, 8)
    }

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 18)
                .frame(width: 280, height: 280)
            // Progress
            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.progress)

            // Timer text
            VStack(spacing: 6) {
                Text(formattedTime)
                    .font(.system(size: 76, weight: .bold, design: .rounded).monospacedDigit())
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
        .foregroundStyle(.white.opacity(0.9))
        .tracking(4)
    }

    // MARK: - Control buttons
    private var controlButtons: some View {
        HStack(spacing: 28) {
            // Stop
            circleButton(icon: "xmark", size: 52, bgOpacity: 0.18) {
                showStopAlert = true
            }
            .accessibilityLabel("Stop training")

            // Pause / Resume (largest)
            circleButton(
                icon: engine.isPaused ? "play.fill" : "pause.fill",
                size: 72, bgOpacity: 0.28
            ) {
                engine.togglePause()
            }
            .accessibilityLabel(engine.isPaused ? "Hervatten" : "Pauzeren")

            // Skip
            circleButton(icon: "forward.end.fill", size: 52, bgOpacity: 0.18) {
                engine.skip()
            }
            .accessibilityLabel("Volgende fase overslaan")
        }
    }

    private func circleButton(icon: String, size: CGFloat, bgOpacity: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(bgOpacity)))
        }
    }

    // MARK: - Helpers
    private var formattedTime: String {
        let m = engine.secondsLeft / 60
        let s = engine.secondsLeft % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var phaseBackground: LinearGradient {
        switch engine.phase {
        case .countdown:
            return LinearGradient(
                colors: [AppTheme.coral.opacity(0.85), AppTheme.amber.opacity(0.8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .work:
            return LinearGradient(
                colors: [Color(hex: 0xE8826B), Color(hex: 0xF4B860)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .rest:
            return LinearGradient(
                colors: [Color(hex: 0x7A9E8A), Color(hex: 0xB8CEAB)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .finished:
            return LinearGradient(
                colors: [Color(hex: 0xA8B89C), Color(hex: 0xFAF6F1)],
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
