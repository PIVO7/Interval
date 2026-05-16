import SwiftUI

enum AppTheme {
    // Brand
    static let coral = Color(hex: 0xE8826B)
    static let amber = Color(hex: 0xF4B860)
    static let sage = Color(hex: 0xA8B89C)
    static let cream = Color(hex: 0xFAF6F1)

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

    static let workGradient = LinearGradient(
        colors: [coral, amber],
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
