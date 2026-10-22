import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(OnboardingState.self) private var onboarding
    @Environment(WorkoutStore.self) private var store
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(ActiveSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .training

    enum AppTab: Hashable { case training, favorites, account }

    var body: some View {
        Group {
            if !onboarding.hasSeenOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: onboarding.hasSeenOnboarding)
    }

    private var mainTabs: some View {
        @Bindable var session = session
        // Outline symbols only — on iOS 26 the system fills the selected
        // tab's icon itself; hard-coding `.fill` makes a tab look
        // permanently selected.
        return TabView(selection: $selection) {
            Tab("Training", systemImage: "stopwatch", value: AppTab.training) {
                HomeView()
            }
            Tab("Favorieten", systemImage: "heart", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("Account", systemImage: "person.crop.circle", value: AppTab.account) {
                AccountView()
            }
        }
        // iPhone: bottom tab bar. iPad: the floating top tab bar that the
        // user can expand into a sidebar (HIG: tab bar or sidebar, never a
        // custom switcher).
        .tabViewStyle(.sidebarAdaptable)
        .modifier(TabBarChrome())
        // Presented from the tab root (not HomeView) so the cover overlays
        // the entire tab UI regardless of the selected tab.
        .fullScreenCover(
            isPresented: $session.isPresentingFullScreen,
            onDismiss: { session.finalizeEnd() }
        ) {
            if let engine = session.engine {
                ActiveTrainingView(
                    engine: engine,
                    onClose: { session.end() }
                )
                .environment(store)
                .environment(audioSettings)
                .environment(pro)
                .environment(appearance)
                .environment(session)
            }
        }
        .onChange(of: store.pendingStart) { _, newValue in
            guard let workout = newValue else { return }
            selection = .training
            session.start(workout, cues: cueOrchestrator)
            store.pendingStart = nil
        }
        // Foreground catch-up: the engine fast-forwards through phases
        // missed while the app was suspended in the background.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { session.engine?.recomputeFromWallClock() }
        }
    }
}

/// iOS 26 tab bar chrome: Liquid Glass minimize-on-scroll. No-op on
/// earlier systems.
private struct TabBarChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

#Preview {
    let audioSettings = AudioSettings()
    RootTabView()
        .environment(WorkoutStore())
        .environment(audioSettings)
        .environment(OnboardingState())
        .environment(AppearanceSettings())
        .environment(CueOrchestrator.makeDefault(settings: audioSettings))
        .environment(StoreManager())
        .environment(ActiveSession())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
