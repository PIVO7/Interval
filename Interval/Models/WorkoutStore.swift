import Foundation
import Observation

@MainActor
@Observable
final class WorkoutStore {
    var current: Workout
    /// Tap-to-start on a favorite. RootTabView switches to Training tab,
    /// HomeView opens the active workout — then clears the flag.
    var pendingStart: Workout?

    init() {
        self.current = Workout(name: NSLocalizedString("Nieuwe training",
                                                       comment: "Default name for an unsaved workout draft"),
                               workSeconds: 30,
                               restSeconds: 15,
                               rounds: 8)
    }

    /// Replace the draft without any side-effects (no tab switch, no start).
    func load(_ workout: Workout) {
        current = workout
    }

    /// Replace the draft AND request immediate start.
    func startWorkout(_ workout: Workout) {
        current = workout
        pendingStart = workout
    }
}
