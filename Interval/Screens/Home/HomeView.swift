import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(ActiveSession.self) private var session
    @Environment(FavoritesSync.self) private var favoritesSync

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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Hero metrics scale with Dynamic Type, relative to the text style they
    // sit next to, so the ring and buttons grow together with the labels.
    @ScaledMetric(relativeTo: .largeTitle) private var compactDurationSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var wideDurationSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var ctaHeight: CGFloat = 60

    /// iPad gets a two-column layout: the
    /// workout ring as hero on the leading side, the settings and actions
    /// on the trailing side. Accessibility text sizes always stack, so the
    /// columns never get squeezed into truncation.
    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if usesWideLayout {
                        VStack(spacing: 20) {
                            header
                            HStack(alignment: .top, spacing: 28) {
                                heroCard
                                VStack(spacing: 20) {
                                    intervalsList
                                    actionButtons
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            header
                            heroCard
                            intervalsList
                            actionButtons
                        }
                    }
                }
                .padding(.horizontal, usesWideLayout ? 32 : 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                // Readable width: wide enough for two real columns on iPad,
                // never a single stretched card across a 13" screen.
                .frame(maxWidth: usesWideLayout ? 1080 : 620)
                .frame(maxWidth: .infinity)
            }
            // Content fits on tall devices — only allow scrolling when
            // it actually overflows (small screens, large Dynamic Type).
            .scrollBounceBehavior(.basedOnSize)
            .background { AmbientBackground().ignoresSafeArea() }
            .navigationTitle("Roundly")
            .navigationBarTitleDisplayMode(.large)
            .toolbarSubtitle(Self.introSubtitle)
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

    private var intervalsList: some View {
        @Bindable var store = store
        return IntervalsListView(
            workSeconds: $store.current.workSeconds,
            restSeconds: $store.current.restSeconds,
            rounds: $store.current.rounds,
            expandedField: $expandedField,
            nudgeWork: nudgeWork
        )
    }

    // Shown as a navigation-bar subtitle on iOS 26+ and as the in-content
    // header row on older systems — one constant so the copy can't drift.
    private static let introSubtitle: LocalizedStringKey =
        "Stel je intervallen in en begin wanneer je klaar bent."

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

    /// Persist the current workout as a favorite, queue it for sync, and
    /// flash the "Opgeslagen" confirmation. Guest mode / unconfigured
    /// backends are not surfaced as errors — the local save is enough.
    private func saveFavorite(_ saved: Workout) {
        // Persists immediately — SwiftData's autosave can lag, and showing
        // the success toast while the row isn't yet on disk risks losing
        // the save if the app dies. The upload is queued and retried by
        // FavoritesSync, so only a local failure is surfaced.
        do {
            try favoritesSync.saveNew(saved)
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

    // MARK: - Header
    // On iOS 26+ the intro line lives in the navigation bar as a subtitle
    // (Apple's iOS 27 kit "Toolbar - Top, Title and Subtitle" pattern);
    // older systems keep it as the first content row.
    private var header: some View {
        Group {
            if #unavailable(iOS 26.0) {
                Text(Self.introSubtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Hero
    // The workout as a ring with the total duration in its centre. Content,
    // not chrome, so it stays a solid card — Liquid Glass is reserved for
    // the controls and navigation layer floating above (HIG).
    private var heroCard: some View {
        VStack(spacing: usesWideLayout ? 24 : 16) {
            WorkoutRingView(
                workSeconds: store.current.workSeconds,
                restSeconds: store.current.restSeconds,
                rounds: store.current.rounds,
                lineWidth: usesWideLayout ? 22 : 16
            ) {
                ringCenter
            }
            .frame(maxWidth: usesWideLayout ? 400 : 240)

            ringLegend
        }
        .padding(usesWideLayout ? 32 : 22)
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var ringCenter: some View {
        VStack(spacing: 4) {
            Text("Totale duur")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(verbatim: store.current.totalSeconds.asCompactDuration)
                .font(.system(
                    size: usesWideLayout ? wideDurationSize : compactDurationSize,
                    weight: .bold,
                    design: .rounded
                ).monospacedDigit())
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.appSmooth, value: store.current.totalSeconds)
            Text("\(store.current.rounds) ronden")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        // One VoiceOver stop: "Totale duur, 5m 45s, 8 ronden".
        .accessibilityElement(children: .combine)
    }

    private var ringLegend: some View {
        HStack(spacing: 20) {
            legendItem("Work", color: AppTheme.coral)
            if store.current.restSeconds > 0 {
                legendItem("Rest", color: AppTheme.sage)
            }
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(AppTheme.secondaryText)
        // The rows below already speak these values; the legend only
        // explains the ring's colours to sighted users.
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }

    // MARK: - Action buttons
    // iOS 26+: Liquid Glass. The primary CTA keeps the brand gradient under
    // clear glass; the favourite button sits beside it as a plain glass
    // control inside one GlassEffectContainer, so the two read as a single
    // floating control group and blend into each other when pressed.
    // Older systems keep the gradient capsule and a soft card circle.
    private var actionButtons: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        // Zelfde oranje als de merk-gradient: de coral→amber
                        // `buttonGradient` onder `.clear` glas i.p.v. een
                        // getinte glassProminent, die het oranje naar dof
                        // baksteen frostte.
                        Button(action: startTraining) {
                            startLabel
                                .foregroundStyle(.white)
                                .glassEffect(.clear.interactive(), in: .capsule)
                                .background(Capsule().fill(AppTheme.buttonGradient))
                        }
                        .buttonStyle(PressableButtonStyle())

                        Button(action: requestSaveFavorite) {
                            saveLabel
                                .foregroundStyle(AppTheme.coralText)
                                .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(justSaved)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: startTraining) {
                        startLabel
                            .background(AppTheme.buttonGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.coralDeep.opacity(0.35), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: requestSaveFavorite) {
                        saveLabel
                            .foregroundStyle(AppTheme.coralText)
                            .background(Capsule().fill(AppTheme.card))
                            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(justSaved)
                }
            }
        }
        .animation(.appSmooth, value: justSaved)
        .padding(.top, 6)
    }

    private var startLabel: some View {
        Label("Training starten", systemImage: "play.fill")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: ctaHeight)
            .contentShape(Capsule())
    }

    /// Icon-only next to the CTA on iPhone (the start button needs the
    /// width); with a title on iPad where the trailing column has room.
    /// Always a full accessibility label either way.
    private var saveLabel: some View {
        Label(
            justSaved ? "Opgeslagen" : "Opslaan als favoriet",
            systemImage: justSaved ? "checkmark" : "heart"
        )
        .labelStyle(SaveLabelStyle(showsTitle: usesWideLayout))
        .font(.system(.title3, design: .rounded, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
        .padding(.horizontal, usesWideLayout ? 22 : 0)
        .frame(minWidth: ctaHeight, minHeight: ctaHeight)
        .contentShape(Capsule())
    }
}

/// `Label` that shows its title only when there is room for it.
private struct SaveLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        if showsTitle {
            HStack(spacing: 8) {
                configuration.icon
                configuration.title
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }
        } else {
            configuration.icon
        }
    }
}

#Preview {
    HomeView()
        .environment(WorkoutStore())
        .environment(AudioSettings())
        .environment(StoreManager())
        .environment(PreviewStore.favoritesSync)
        .modelContainer(PreviewStore.container)
}
