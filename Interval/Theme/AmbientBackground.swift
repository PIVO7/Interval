import SwiftUI

/// Warm, very soft backdrop for the main screens: the flat cream (or warm
/// near-black) with faint coral, amber and sage glows in the corners.
///
/// Liquid Glass needs something to refract — over a perfectly flat fill the
/// tab bar, toolbar and glass buttons read as grey plastic. These glows are
/// kept well below the card fills so content contrast is unchanged; they
/// only give the glass layer a hint of the brand colours to pick up.
/// Static on purpose (no animated mesh): it sits behind a screen that stays
/// open for a long time and shouldn't cost battery.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.55, 0], [1, 0],
                [0, 0.45], [0.6, 0.5], [1, 0.4],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: colorScheme == .dark ? Self.darkColors : Self.lightColors
        )
    }

    // Corners carry the glow, the centre stays the plain base tone.
    private static let lightColors: [Color] = [
        Color(hex: 0xF9DED2), Color(hex: 0xFBEDE3), Color(hex: 0xFCEBD3),
        Color(hex: 0xFAF0E9), AppTheme.cream,       AppTheme.cream,
        Color(hex: 0xEFF1E8), AppTheme.cream,       Color(hex: 0xFBF1E4),
    ]

    private static let darkColors: [Color] = [
        Color(hex: 0x33221D), Color(hex: 0x261E1A), Color(hex: 0x31281B),
        Color(hex: 0x221D1A), AppTheme.darkBg,      AppTheme.darkBg,
        Color(hex: 0x1F241E), AppTheme.darkBg,      Color(hex: 0x241F19),
    ]
}

#Preview {
    AmbientBackground().ignoresSafeArea()
}
