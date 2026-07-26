import SwiftUI

struct AvatarBadge: View {
    let profile: PlayerProfile
    var size: CGFloat = 44

    private var color: Color {
        let palette: [Color] = [
            AppTheme.coral,
            AppTheme.sky,
            AppTheme.gold,
            Color(red: 0.55, green: 0.75, blue: 0.35),
            Color(red: 0.75, green: 0.45, blue: 0.70),
            Color(red: 0.40, green: 0.45, blue: 0.55)
        ]
        return palette[profile.avatarColorIndex % palette.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = profile.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(profile.name.prefix(2)).uppercased()
    }
}
