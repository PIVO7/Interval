import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var store: WorkoutStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if store.favorites.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Favorieten")
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.favorites) { workout in
                    favoriteRow(workout)
                }
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func favoriteRow(_ workout: Workout) -> some View {
        Button {
            store.load(workout)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.coral.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "timer")
                        .foregroundStyle(AppTheme.coral)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(workout.summary)
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
    FavoritesView().environmentObject(WorkoutStore())
}
