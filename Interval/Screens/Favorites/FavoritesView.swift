import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(StoreManager.self) private var pro
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutEntity.createdAt, order: .reverse)
    private var favorites: [WorkoutEntity]

    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false
    @State private var editingEntity: WorkoutEntity?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Favorieten")
            .alert("Synchroniseren mislukt", isPresented: $showSyncErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncErrorMessage ?? "")
            }
            .sheet(item: $editingEntity) { entity in
                EditFavoriteSheet(entity: entity) {
                    syncEditedFavorite(entity)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var list: some View {
        List {
            ForEach(favorites) { entity in
                FavoriteRowView(
                    entity: entity,
                    onStart: { store.startWorkout(entity.toWorkout()) },
                    onEdit: { editingEntity = entity }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteFavorite(entity)
                    } label: {
                        Label("Verwijderen", systemImage: "trash")
                    }
                }
                // VoiceOver can't discover swipe-to-delete; expose it
                // explicitly as a rotor action.
                .accessibilityAction(named: Text("Verwijder \(entity.name)")) {
                    deleteFavorite(entity)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    /// Optimistic delete with rollback: remove locally first for snappy
    /// UX, then push to Supabase. If the remote delete fails (and we're
    /// signed in), re-insert the row from the snapshot so the user doesn't
    /// lose data due to a transient network blip.
    private func deleteFavorite(_ entity: WorkoutEntity) {
        let snapshot = (
            id: entity.id,
            name: entity.name,
            workSeconds: entity.workSeconds,
            restSeconds: entity.restSeconds,
            rounds: entity.rounds,
            createdAt: entity.createdAt
        )
        modelContext.delete(entity)
        do {
            try modelContext.save()
        } catch {
            // Couldn't even persist the delete locally — surface it and
            // bail before touching the network, so the row doesn't quietly
            // reappear on next launch with no explanation.
            syncErrorMessage = error.localizedDescription
            showSyncErrorAlert = true
            return
        }
        Task {
            do {
                try await SupabaseManager.shared.deleteWorkout(id: snapshot.id)
            } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
                // Guest mode or unconfigured — local delete is authoritative.
            } catch {
                // Rollback the local delete so the user can retry.
                let restored = WorkoutEntity(
                    id: snapshot.id,
                    name: snapshot.name,
                    workSeconds: snapshot.workSeconds,
                    restSeconds: snapshot.restSeconds,
                    rounds: snapshot.rounds,
                    createdAt: snapshot.createdAt
                )
                modelContext.insert(restored)
                try? modelContext.save()
                syncErrorMessage = error.localizedDescription
                showSyncErrorAlert = true
            }
        }
    }

    private func syncEditedFavorite(_ entity: WorkoutEntity) {
        Task {
            do {
                try await SupabaseManager.shared.upsertWorkout(entity.toWorkout())
            } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
                // Guest mode or unconfigured — local edit is enough.
            } catch {
                syncErrorMessage = error.localizedDescription
                showSyncErrorAlert = true
            }
        }
    }

    /// Empty state doubles as a soft Pro entry point: free users see what
    /// favorites are for and can open the paywall right here instead of
    /// discovering the gate mid-save on the training screen.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nog geen favorieten", systemImage: "heart")
        } description: {
            Text(pro.isUnlocked
                 ? "Sla je veelgebruikte intervallen op vanaf het trainingsscherm."
                 : "Bewaar je veelgebruikte intervallen met Interval Pro.")
        } actions: {
            if !pro.isUnlocked {
                Button("Ontgrendel favorieten") { showPaywall = true }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.coral)
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environment(WorkoutStore())
        .environment(StoreManager())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
