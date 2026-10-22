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
            .toolbarSubtitle("Je opgeslagen trainingen.")
            .alert("Verwijderen mislukt", isPresented: $showSyncErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncErrorMessage ?? "")
            }
            .sheet(item: $editingEntity) { entity in
                EditFavoriteSheet(entity: entity)
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

    /// Delete and persist right away; iCloud sync carries the delete to
    /// the user's other devices.
    private func deleteFavorite(_ entity: WorkoutEntity) {
        modelContext.delete(entity)
        do {
            try modelContext.save()
        } catch {
            // Couldn't even persist the delete locally — surface it so the
            // row doesn't quietly reappear on next launch with no explanation.
            syncErrorMessage = error.localizedDescription
            showSyncErrorAlert = true
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
                 : "Bewaar je veelgebruikte intervallen met Roundly Pro.")
        } actions: {
            if !pro.isUnlocked {
                // iOS 26+: the kit's "Glass Prominent" capsule, matching the
                // Home screen's primary CTA. Bordered-prominent fallback.
                if #available(iOS 26.0, *) {
                    // Large/bold like the Home CTA — white on coralDeep is
                    // ≈3.8:1, which only passes WCAG as large text.
                    Button("Ontgrendel favorieten") { showPaywall = true }
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(AppTheme.coralDeep)
                } else {
                    Button("Ontgrendel favorieten") { showPaywall = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.coral)
                }
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
