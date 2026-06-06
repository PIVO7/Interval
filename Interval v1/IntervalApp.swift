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

    init() {
        // Cue stack is constructed once and shared across workouts.
        // Lifecycle (prepareForWorkout / workoutDidEnd) is per-workout
        // and driven by `TimerEngine`.
        let settings = AudioSettings()
        _audioSettings = State(initialValue: settings)
        _cueOrchestrator = State(initialValue: .makeDefault(settings: settings))
    }

    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: WorkoutEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(workoutStore)
                .environment(audioSettings)
                .environment(auth)
                .environment(appearance)
                .environment(cueOrchestrator)
                .environment(store)
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
