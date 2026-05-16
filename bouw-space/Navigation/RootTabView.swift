import SwiftUI

struct RootTabView: View {
    @State private var selection: Tab = .training

    enum Tab: Hashable { case training, favorites, account }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("Training", systemImage: "timer")
                }
                .tag(Tab.training)

            FavoritesView()
                .tabItem {
                    Label("Favorieten", systemImage: "heart.fill")
                }
                .tag(Tab.favorites)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(Tab.account)
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(WorkoutStore())
}
