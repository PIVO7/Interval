import SwiftUI
import SwiftData

struct FavoritesView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutEntity.createdAt, order: .reverse)
    private var favorites: [WorkoutEntity]

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
                            Task { try? await SupabaseManager.shared.deleteWorkout(id: id) }
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
        Button {
            store.load(entity.toWorkout())
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.coral.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "timer")
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
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(16)
            .softCard()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(AppTheme.coral.opacity(0.12)).frame(width: 88, height: 88)
                Image(systemName: "heart")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(AppTheme.coral)
            }
            Text("Nog geen favorieten")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Sla je veelgebruikte intervallen op vanaf het trainingsscherm.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    FavoritesView()
        .environmentObject(WorkoutStore())
        .modelContainer(for: WorkoutEntity.self, inMemory: true)
}
