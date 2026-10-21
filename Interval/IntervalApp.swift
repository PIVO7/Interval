import SwiftUI
import SwiftData

@main
struct IntervalApp: App {
    @State private var workoutStore = WorkoutStore()
    // No default here — built once in init() and shared with the cue stack,
    // so there's no throwaway instance.
    @State private var audioSettings: AudioSettings
    @State private var auth = AuthManager()
    @State private var appearance = AppearanceSettings()
    @State private var store = StoreManager()
    @State private var cueOrchestrator: CueOrchestrator
    @State private var activeSession = ActiveSession()
    @State private var favoritesSync: FavoritesSync

    let modelContainer: ModelContainer

    init() {
        // Cue stack is constructed once and shared across workouts.
        // Lifecycle (prepareForWorkout / workoutDidEnd) is per-workout
        // and driven by `TimerEngine`.
        let settings = AudioSettings()
        _audioSettings = State(initialValue: settings)
        _cueOrchestrator = State(initialValue: .makeDefault(settings: settings))
        let container: ModelContainer
        do {
            container = try ModelContainer(for: WorkoutEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        modelContainer = container
        // Sync works on the same main context the views' @Query reads, so
        // reconciled changes show up immediately.
        _favoritesSync = State(initialValue: FavoritesSync(
            context: container.mainContext,
            remote: SupabaseManager.shared
        ))
        Self.applyRoundedNavigationTitles()
    }

    /// SwiftUI has no modifier for navigation-bar title fonts, so the rounded
    /// design comes in via the UIKit appearance proxy. Only the fonts are set —
    /// the bar background stays untouched so the system look keeps working.
    private static func applyRoundedNavigationTitles() {
        func roundedFont(style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let size = UIFont.preferredFont(forTextStyle: style).pointSize
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
        }
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [.font: roundedFont(style: .largeTitle, weight: .bold)]
        navigationBar.titleTextAttributes = [.font: roundedFont(style: .headline, weight: .semibold)]
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(workoutStore)
                .environment(audioSettings)
                .environment(auth)
                .environment(appearance)
                .environment(cueOrchestrator)
                .environment(store)
                .environment(activeSession)
                .environment(favoritesSync)
                .tint(AppTheme.coral)
                .preferredColorScheme(appearance.mode.colorScheme)
                .task {
                    // Load the Pro product and reconcile entitlements at launch.
                    await store.start()
                }
        }
        .modelContainer(modelContainer)
    }
}
