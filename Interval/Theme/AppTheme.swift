import SwiftUI

enum AppTheme {
    // Brand
    static let coral = Color(hex: 0xE8826B)
    static let amber = Color(hex: 0xF4B860)
    static let sage = Color(hex: 0xA8B89C)
    static let cream = Color(hex: 0xFAF6F1)

    // Deeper variants = the bottom stop of the full-screen workout gradients.
    // White text sits over the gradient; these deep stops (≈3.8:1 / ≈4.0:1
    // white contrast) carry the lower half, while the large, heavy timer
    // numerals stay legible over the lighter top stops. Not WCAG-AA against
    // the base stops — see PhaseTheme for the trade-off.
    static let coralDeep = Color(hex: 0xC76A48)
    static let sageDeep  = Color(hex: 0x5B8071)
    static let forestDeep = Color(hex: 0x3D6353)  // accent for finished/celebration

    // Dark
    static let darkBg = Color(hex: 0x1C1A18)
    static let darkCard = Color(hex: 0x2A2724)

    // Text
    static let textPrimary = Color(hex: 0x2B2B2B)
    static let textSecondary = Color(hex: 0x7A7A7A)
    static let error = Color(hex: 0xD9534F)

    // Adaptive
    static var background: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x1C/255, green: 0x1A/255, blue: 0x18/255, alpha: 1)
                : UIColor(red: 0xFA/255, green: 0xF6/255, blue: 0xF1/255, alpha: 1)
        })
    }

    static var card: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x2A/255, green: 0x27/255, blue: 0x24/255, alpha: 1)
                : UIColor.white
        })
    }

    static var primaryText: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.96, alpha: 1)
                : UIColor(red: 0x2B/255, green: 0x2B/255, blue: 0x2B/255, alpha: 1)
        })
    }

    static var secondaryText: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.65, alpha: 1)
                : UIColor(red: 0x7A/255, green: 0x7A/255, blue: 0x7A/255, alpha: 1)
        })
    }

    // Text-safe brand tints. The base coral/amber/sage read fine as fills,
    // but as *text* on cream/white they land around 1.9–2.5:1. These darker
    // stops hit ≥4.5:1 on cream and on the tinted value chips; in dark mode
    // the base tints already clear 5.5:1 on darkBg/darkCard, so they stay.
    static var coralText: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xE8/255, green: 0x82/255, blue: 0x6B/255, alpha: 1)
                : UIColor(red: 0xAC/255, green: 0x55/255, blue: 0x35/255, alpha: 1)
        })
    }

    static var amberText: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xF4/255, green: 0xB8/255, blue: 0x60/255, alpha: 1)
                : UIColor(red: 0x96/255, green: 0x63/255, blue: 0x1A/255, alpha: 1)
        })
    }

    static var sageText: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xA8/255, green: 0xB8/255, blue: 0x9C/255, alpha: 1)
                : UIColor(red: 0x56/255, green: 0x7A/255, blue: 0x64/255, alpha: 1)
        })
    }

    static let workGradient = LinearGradient(
        colors: [coral, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Deeper coral→amber run for buttons that carry a white label. The base
    // workGradient bottoms out at ~1.8:1 against white near the amber stop;
    // these stops keep ≥3.3:1 (large-bold threshold is 3:1) across the run
    // while staying decorative-bright for icon circles via workGradient.
    static let buttonGradient = LinearGradient(
        colors: [Color(hex: 0xD96A4E), Color(hex: 0xC07E24)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let restGradient = LinearGradient(
        colors: [sage, cream],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Card style
struct SoftCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.card)
                    .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
            )
    }
}

extension View {
    func softCard() -> some View { modifier(SoftCard()) }
}

// MARK: - Toolbar subtitle
/// Apple's iOS 27 kit "Toolbar - Top, Title and Subtitle" pattern: a screen's
/// intro line lives under the large navigation title. `navigationSubtitle`
/// only exists on iOS 26+, so this is a no-op on earlier systems — callers
/// keep their own in-content fallback where one is needed.
extension View {
    @ViewBuilder
    func toolbarSubtitle(_ subtitle: LocalizedStringKey) -> some View {
        if #available(iOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }
}

// MARK: - Liquid Glass surface
/// Subtle Liquid Glass backdrop for controls sitting on the vibrant workout
/// gradients (iOS 26+). Falls back to the original translucent-white fill on
/// earlier systems so the layout doesn't shift between OS generations.
struct LiquidGlassSurface: ViewModifier {
    let shape: AnyShape
    let fallbackOpacity: Double
    /// Interactive glass reacts to touches with the system's shimmer;
    /// disable for non-tappable surfaces like cards.
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(interactive), in: shape)
        } else {
            content.background(shape.fill(Color.white.opacity(fallbackOpacity)))
        }
    }
}

extension View {
    func liquidGlassSurface(
        in shape: some Shape,
        fallbackOpacity: Double,
        interactive: Bool = true
    ) -> some View {
        modifier(LiquidGlassSurface(
            shape: AnyShape(shape),
            fallbackOpacity: fallbackOpacity,
            interactive: interactive
        ))
    }
}

// MARK: - Button press feedback
/// Press-down shrink + dim for the big gradient CTAs, mirroring the tactile
/// response the list rows get from their RowButtonStyle. Without this the
/// primary buttons give no visual feedback at all on touch.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
