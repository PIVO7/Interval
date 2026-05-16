import SwiftUI

@main
struct IntervalApp: App {
    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var audioSettings = AudioSettings()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(workoutStore)
                .environmentObject(audioSettings)
                .tint(AppTheme.coral)
        }
    }
}
