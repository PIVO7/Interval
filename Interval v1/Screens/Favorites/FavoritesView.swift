import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutEntity.createdAt, order: .reverse)
    private var favorites: [WorkoutEntity]

    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false
    @State private var editingEntity: WorkoutEntity?

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
        }
    }

    private var list: some View {
        List {
            ForEach(favorites) { entity in
                favoriteRow(entity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            let id = entity.id
                            modelContext.delete(entity)
                            Task {
                                do {
                                    try await SupabaseManager.shared.deleteWorkout(id: id)
                                } catch SupabaseError.notSignedIn, SupabaseError.notConfigured {
                                    // Guest mode or unconfigured — local delete is enough.
                                } catch {
                                    syncErrorMessage = error.localizedDescription
                                    showSyncErrorAlert = true
                                }
                            }
                        } label: {
                            Label("Verwijderen", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    /// Each row is split into THREE zones with clearly distinct affordances:
    ///   - Play circle (left, coral, tap target 44pt) → starts the workout.
    ///   - Descriptive text (middle) → read-only display, NOT tappable.
    ///   - Adjust icon (right, neutral, tap target 44pt) → opens the edit sheet.
    /// Swipe-to-delete is handled by the parent List.
    private func favoriteRow(_ entity: WorkoutEntity) -> some View {
        HStack(spacing: 16) {
            Button {
                store.startWorkout(entity.toWorkout())
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.coral.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .foregroundStyle(AppTheme.coral)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(entity.name)")

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(entity.summary)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button {
                editingEntity = entity
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.coral.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(AppTheme.secondaryText)
                        .font(.callout.weight(.semibold))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bewerk \(entity.name)")
        }
        .padding(16)
        .softCard()
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nog geen favorieten", systemImage: "heart")
        } description: {
            Text("Sla je veelgebruikte intervallen op vanaf het trainingsscherm.")
        }
    }
}

#Preview {
    FavoritesView()
        .environment(WorkoutStore())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
