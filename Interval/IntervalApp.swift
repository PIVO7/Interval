import SwiftUI
import SwiftData
import os

@main
struct IntervalApp: App {
    @State private var workoutStore = WorkoutStore()
    // No default here — built once in init() and shared with the cue stack,
    // so there's no throwaway instance.
    @State private var audioSettings: AudioSettings
    @State private var onboarding = OnboardingState()
    @State private var appearance = AppearanceSettings()
    @State private var store = StoreManager()
    @State private var cueOrchestrator: CueOrchestrator
    @State private var activeSession = ActiveSession()

    let modelContainer: ModelContainer = Self.makeModelContainer()

    init() {
        // Cue stack is constructed once and shared across workouts.
        // Lifecycle (prepareForWorkout / workoutDidEnd) is per-workout
        // and driven by `TimerEngine`.
        let settings = AudioSettings()
        _audioSettings = State(initialValue: settings)
        _cueOrchestrator = State(initialValue: .makeDefault(settings: settings))
        Self.applyRoundedNavigationTitles()
    }

    /// Favorites live in SwiftData and sync through the user's private
    /// iCloud database (`.automatic` picks the container from the
    /// entitlements). Without an iCloud account the store simply stays
    /// local. If the CloudKit-backed store can't be opened at all, fall
    /// back to a local-only store rather than crash at launch.
    nonisolated private static func makeModelContainer() -> ModelContainer {
        let log = Logger(subsystem: "com.superapp.interval", category: "Storage")
        do {
            return try ModelContainer(
                for: WorkoutEntity.self,
                configurations: ModelConfiguration(cloudKitDatabase: .automatic)
            )
        } catch {
            log.error("CloudKit store unavailable, using local store: \(error.localizedDescription, privacy: .public)")
        }
        do {
            return try ModelContainer(
                for: WorkoutEntity.self,
                configurations: ModelConfiguration(cloudKitDatabase: .none)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
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
                .environment(onboarding)
                .environment(appearance)
                .environment(cueOrchestrator)
                .environment(store)
                .environment(activeSession)
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
