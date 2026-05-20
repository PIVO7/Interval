import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutEntity.createdAt, order: .reverse)
    private var favorites: [WorkoutEntity]

    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false

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

    private func favoriteRow(_ entity: WorkoutEntity) -> some View {
        HStack(spacing: 0) {
            // Primary tap area: name + summary → start the workout immediately.
            Button {
                store.startWorkout(entity.toWorkout())
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(AppTheme.coral.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: "play.fill")
                            .foregroundStyle(AppTheme.coral)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entity.name)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(entity.summary)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(entity.name)")

            // Secondary tap area: edit icon → load into editor without starting.
            Button {
                store.loadForEditing(entity.toWorkout())
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
