import Foundation
import Observation

@MainActor
@Observable
final class WorkoutStore {
    var current: Workout
    /// Tap-to-start on a favorite. RootTabView switches to Training tab,
    /// HomeView opens the active workout — then clears the flag.
    var pendingStart: Workout?
    /// Edit-and-load on a favorite. RootTabView switches to Training tab,
    /// no auto-start. User can tweak then tap Start themselves.
    var pendingEdit: Workout?

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

    /// Replace the draft AND switch the user to the Training tab so they can
    /// tweak the values before starting. No auto-start.
    func loadForEditing(_ workout: Workout) {
        current = workout
        pendingEdit = workout
    }

    /// Replace the draft AND request immediate start.
    func startWorkout(_ workout: Workout) {
        current = workout
        pendingStart = workout
    }
}
