import Foundation
import SwiftUI

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var current: Workout
    @Published var favorites: [Workout]

    init() {
        self.current = Workout(name: "Nieuwe training", workSeconds: 30, restSeconds: 15, rounds: 8)
        // Lege favorieten-lijst by default; placeholder list voor visuele rijkheid.
        self.favorites = [
            Workout(name: "Tabata 30/15", workSeconds: 30, restSeconds: 15, rounds: 8),
            Workout(name: "HIIT 40/20", workSeconds: 40, restSeconds: 20, rounds: 10),
            Workout(name: "Revalidatie rustig", workSeconds: 45, restSeconds: 30, rounds: 6)
        ]
    }

    func addFavorite(_ workout: Workout) {
        favorites.insert(workout, at: 0)
    }

    func removeFavorite(_ workout: Workout) {
        favorites.removeAll { $0.id == workout.id }
    }

    func load(_ workout: Workout) {
        current = workout
    }
}
