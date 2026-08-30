import SwiftUI
import SwiftData
import os

struct RootTabView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(WorkoutStore.self) private var store
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(CueOrchestrator.self) private var cueOrchestrator
    @Environment(StoreManager.self) private var pro
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(ActiveSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .training

    private let log = Logger(subsystem: "com.superapp.interval", category: "Sync")

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
        // Pull remote favorites into the local store — at launch when a
        // session is already present, and again the moment the async
        // Apple→Supabase bridge lands a user id after sign-in (`task(id:)`
        // re-runs on id change). This is what makes "je favorieten op al
        // je apparaten" true on a second device; without it the app only
        // ever uploads. Additive merge: WorkoutEntity.id is unique, so
        // inserts upsert in place and local-only favorites are kept.
        .task(id: auth.user?.supabaseUserId) {
            await pullRemoteFavorites()
        }
    }

    private func pullRemoteFavorites() async {
        guard auth.user?.supabaseUserId != nil else { return }
        do {
            let remote = try await SupabaseManager.shared.fetchWorkouts()
            guard !remote.isEmpty else { return }
            for workout in remote {
                modelContext.insert(WorkoutEntity(from: workout))
            }
            try modelContext.save()
        } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
            // Guest mode or unconfigured backend — local-only is fine.
        } catch {
            // Best-effort: a failed pull never blocks the UI; the next
            // launch/sign-in retries.
            log.warning("Favorites pull failed: \(error.localizedDescription, privacy: .public)")
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
