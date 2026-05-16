import Foundation
import SwiftUI

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var current: Workout

    init() {
        self.current = Workout(name: NSLocalizedString("Nieuwe training",
                                                       comment: "Default name for an unsaved workout draft"),
                               workSeconds: 30,
                               restSeconds: 15,
                               rounds: 8)
    }

    func load(_ workout: Workout) {
        current = workout
    }
}
