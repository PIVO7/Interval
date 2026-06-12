import SwiftUI
import SwiftData
import os

struct RootTabView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .training

    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "Sync")

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
        // Pull remote favorites into the local store — at launch when a
        // session is already present, and again the moment the async
        // Apple→Supabase bridge lands a user id after sign-in (`task(id:)`
        // re-runs on id change). This is what makes "je favorieten op al
        // je apparaten" true on a second device; without it the app only
        // ever uploads. Additive merge: WorkoutEntity.id is unique, so
        // inserts upsert in place and local-only favorites are kept.
        .task(id: auth.user?.supabaseUserId) {
            await pullRemoteFavorites()
        }
    }

    private func pullRemoteFavorites() async {
        guard auth.user?.supabaseUserId != nil else { return }
        do {
            let remote = try await SupabaseManager.shared.fetchWorkouts()
            guard !remote.isEmpty else { return }
            for workout in remote {
                modelContext.insert(WorkoutEntity(from: workout))
            }
            try modelContext.save()
        } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
            // Guest mode or unconfigured backend — local-only is fine.
        } catch {
            // Best-effort: a failed pull never blocks the UI; the next
            // launch/sign-in retries.
            log.warning("Favorites pull failed: \(error.localizedDescription, privacy: .public)")
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
