import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(WorkoutStore.self) private var store
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(ActiveSession.self) private var session
    @Environment(FavoritesSync.self) private var favoritesSync
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .training
    @State private var showCloudConnectError = false

    enum AppTab: Hashable { case training, favorites, account }

    var body: some View {
        Group {
            if !auth.hasSeenOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: auth.hasSeenOnboarding)
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
                .environment(favoritesSync)
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
            guard newPhase == .active else { return }
            session.engine?.recomputeFromWallClock()
            // Retry anything queued while offline or in the background.
            if auth.user?.supabaseUserId != nil { favoritesSync.requestSync() }
        }
        // Sync favorites with the server — at launch when a session is
        // already present, and again the moment the async Apple→Supabase
        // bridge lands a user id after sign-in (`task(id:)` re-runs on id
        // change). Pushes queued local changes and reconciles edits and
        // deletes from other devices; see FavoritesSync.
        .task(id: auth.user?.supabaseUserId) {
            guard auth.user?.supabaseUserId != nil else { return }
            await favoritesSync.sync()
        }
        // Signed in with Apple but the cloud connection failed: say so,
        // instead of letting the user believe their favorites sync. The
        // Account tab offers the retry.
        .onChange(of: auth.cloudErrorVersion) { _, _ in
            showCloudConnectError = true
        }
        .alert("Synchronisatie niet verbonden", isPresented: $showCloudConnectError) {
            Button("Naar Account") { selection = .account }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Je bent ingelogd, maar de verbinding met de cloud is mislukt. Je favorieten worden voorlopig alleen op dit toestel bewaard. Probeer opnieuw via Account.")
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
        .environment(AuthManager())
        .environment(AppearanceSettings())
        .environment(CueOrchestrator.makeDefault(settings: audioSettings))
        .environment(StoreManager())
        .environment(ActiveSession())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
