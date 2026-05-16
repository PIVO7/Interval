import SwiftUI

@main
struct IntervalApp: App {
    @StateObject private var workoutStore = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(workoutStore)
                .tint(AppTheme.coral)
        }
    }
}
