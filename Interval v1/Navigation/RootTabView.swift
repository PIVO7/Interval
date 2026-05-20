import SwiftUI

struct RootTabView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(WorkoutStore.self) private var store
    @State private var selection: AppTab = .training

    enum AppTab: Hashable { case training, favorites, account }

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
            Tab("Training", systemImage: "timer", value: AppTab.training) {
                HomeView()
            }
            Tab("Favorieten", systemImage: "heart.fill", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("Account", systemImage: "person.crop.circle", value: AppTab.account) {
                AccountView()
            }
        }
        .onChange(of: store.pendingStart) { _, newValue in
            if newValue != nil { selection = .training }
        }
        .onChange(of: store.pendingEdit) { _, newValue in
            if newValue != nil {
                selection = .training
                store.pendingEdit = nil  // consumed — no further action needed
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(WorkoutStore())
        .environment(AudioSettings())
        .environment(AuthManager())
        .environment(AppearanceSettings())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
