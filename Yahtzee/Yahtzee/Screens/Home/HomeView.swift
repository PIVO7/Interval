import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profileStore

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        Text("Yahtzee")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.cream)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                        Text("Gooi, reken en win samen")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.cream.opacity(0.9))
                    }
                    .padding(.bottom, 36)

                    VStack(spacing: 14) {
                        NavigationLink(value: Destination.setup(.versusFriends)) {
                            menuLabel("Tegen elkaar", subtitle: "Samen op één iPhone of iPad")
                        }
                        NavigationLink(value: Destination.setup(.versusComputer)) {
                            menuLabel("Tegen de computer", subtitle: "Solo uitdaging")
                        }
                        NavigationLink(value: Destination.profiles) {
                            menuLabel("Profielen", subtitle: winsSubtitle)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .profiles:
                    ProfilesView()
                case .setup(let mode):
                    GameSetupView(mode: mode)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var winsSubtitle: String {
        let total = profileStore.humanProfiles.reduce(0) { $0 + $1.wins }
        if profileStore.humanProfiles.isEmpty {
            return "Maak eerst een speler aan"
        }
        return "\(profileStore.humanProfiles.count) spelers · \(total) overwinningen"
    }

    private var background: some View {
        LinearGradient(
            colors: [AppTheme.felt, AppTheme.feltDeep, Color(red: 0.03, green: 0.18, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            DicePattern()
                .opacity(0.12)
                .ignoresSafeArea()
        }
    }

    private func menuLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.cream.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

enum Destination: Hashable {
    case profiles
    case setup(GameMode)
}

private struct DicePattern: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 56
            for x in stride(from: 0, through: size.width, by: step) {
                for y in stride(from: 0, through: size.height, by: step) {
                    var path = Path(roundedRect: CGRect(x: x, y: y, width: 18, height: 18), cornerRadius: 4)
                    context.fill(path, with: .color(.white))
                }
            }
        }
    }
}
