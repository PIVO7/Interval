import SwiftUI

/// The app icon's look as an in-app medallion: a white glyph over the deep
/// coral→amber `buttonGradient`. On iOS 26+ the glyph floats on Liquid Glass
/// that samples the gradient beneath it — echoing the icon's frosted glass
/// layers — with a plain gradient circle on earlier systems.
struct BrandIconCircle<Glyph: View>: View {
    var size: CGFloat = 64
    @ViewBuilder var glyph: Glyph

    var body: some View {
        if #available(iOS 26.0, *) {
            // `.clear` glass keeps the gradient saturated underneath while
            // still adding the icon-style specular rim; `.regular` frosts
            // the small circle out to a pale wash on light backgrounds.
            glyphContent
                .glassEffect(.clear, in: .circle)
                .background(Circle().fill(AppTheme.buttonGradient))
        } else {
            ZStack {
                Circle().fill(AppTheme.buttonGradient)
                glyphContent
            }
            .frame(width: size, height: size)
        }
    }

    private var glyphContent: some View {
        glyph
            .foregroundStyle(.white)
            .frame(width: size, height: size)
    }
}
