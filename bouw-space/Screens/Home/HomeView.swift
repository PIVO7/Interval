import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showSaveSheet = false
    @State private var showActive = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        summaryCard
                        TimePickerCard(
                            title: "Work",
                            systemImage: "flame.fill",
                            tint: AppTheme.coral,
                            seconds: $store.current.workSeconds,
                            minSeconds: 5,
                            maxSeconds: 3600
                        )
                        TimePickerCard(
                            title: "Rest",
                            systemImage: "leaf.fill",
                            tint: AppTheme.sage,
                            seconds: $store.current.restSeconds,
                            minSeconds: 0,
                            maxSeconds: 3600
                        )
                        RoundsCard(rounds: $store.current.rounds)
                        actionButtons
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Interval")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSaveSheet) {
                SaveFavoriteSheet(workout: store.current) { saved in
                    store.addFavorite(saved)
                }
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showActive) {
                ActiveTrainingView(workout: store.current)
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Klaar voor je sessie")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Stel je intervallen in en begin wanneer je klaar bent.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.workGradient)
                    .frame(width: 56, height: 56)
                Image(systemName: "bolt.heart.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Totale duur")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(totalDurationText)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(store.current.summary)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .padding(20)
        .softCard()
    }

    private var totalDurationText: String {
        let total = store.current.totalSeconds
        let m = total / 60
        let s = total % 60
        if m == 0 { return "\(s)s" }
        return s == 0 ? "\(m) min" : "\(m) min \(s)s"
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showSaveSheet = true
            } label: {
                Label("Opslaan als favoriet", systemImage: "heart")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().stroke(AppTheme.coral.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(AppTheme.coral)
            }
            .accessibilityLabel("Opslaan als favoriet")

            Button {
                showActive = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start training")
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.workGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: AppTheme.coral.opacity(0.35), radius: 14, x: 0, y: 8)
            }
            .accessibilityLabel("Start training")
        }
        .padding(.top, 6)
    }
}

#Preview {
    HomeView()
        .environmentObject(WorkoutStore())
}
