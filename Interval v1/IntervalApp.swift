import SwiftUI
import SwiftData

@main
struct IntervalApp: App {
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var audioSettings = AudioSettings()
    @StateObject private var auth = AuthManager()

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
                .environmentObject(workoutStore)
                .environmentObject(audioSettings)
                .environmentObject(auth)
                .tint(AppTheme.coral)
        }
        .modelContainer(modelContainer)
    }
}
