import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selection: Tab = .training

    enum Tab: Hashable { case training, favorites, account }

    var body: some View {
        Group {
            if !auth.hasSeenOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: auth.hasSeenOnboarding)
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Training", systemImage: "timer") }
                .tag(Tab.training)

            FavoritesView()
                .tabItem { Label("Favorieten", systemImage: "heart.fill") }
                .tag(Tab.favorites)

            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(Tab.account)
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(WorkoutStore())
        .environmentObject(AudioSettings())
        .environmentObject(AuthManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
