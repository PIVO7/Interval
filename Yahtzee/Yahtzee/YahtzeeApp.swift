import SwiftUI

@main
struct YahtzeeApp: App {
    @State private var profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(profileStore)
        }
    }
}
