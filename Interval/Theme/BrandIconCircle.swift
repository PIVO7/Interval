import SwiftUI

/// The app icon's look as an in-app medallion: a white glyph over the deep
/// coral→amber `buttonGradient`. Deliberately no Liquid Glass — it sits in
/// cards as content, and the HIG reserves glass for controls and the
/// navigation layer.
struct BrandIconCircle<Glyph: View>: View {
    var size: CGFloat = 64
    @ViewBuilder var glyph: Glyph

    var body: some View {
        ZStack {
            Circle().fill(AppTheme.buttonGradient)
            glyph
                .foregroundStyle(.white)
                // Mirrors the app icon's neutral drop shadow under its
                // solid-white glyph layers.
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}
