import SwiftUI
import SwiftData

@main
struct IntervalApp: App {
    @State private var workoutStore = WorkoutStore()
    @State private var audioSettings = AudioSettings()
    @State private var auth = AuthManager()
    @State private var appearance = AppearanceSettings()

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
                .tint(AppTheme.coral)
                .preferredColorScheme(appearance.mode.colorScheme)
        }
        .modelContainer(modelContainer)
    }
}
