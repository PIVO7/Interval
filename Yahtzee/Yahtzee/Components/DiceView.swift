import SwiftUI

struct DiceTrayView: View {
    let dice: [Die]
    let isRolling: Bool
    let canInteract: Bool
    let onToggle: (UUID) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(dice) { die in
                DieView(die: die, isRolling: isRolling && !die.isHeld)
                    .onTapGesture {
                        guard canInteract else { return }
                        onToggle(die.id)
                    }
                    .accessibilityLabel("Dobbelsteen \(die.value)")
                    .accessibilityHint(die.isHeld ? "Vastgehouden, tik om los te laten" : "Tik om vast te houden")
                    .accessibilityAddTraits(die.isHeld ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }
}

struct DieView: View {
    let die: Die
    let isRolling: Bool

    @State private var spin = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(die.isHeld ? AppTheme.held : AppTheme.cream)
                .shadow(color: .black.opacity(0.25), radius: die.isHeld ? 2 : 6, y: 3)

            DiePips(value: die.value)
                .foregroundStyle(AppTheme.ink)
        }
        .frame(width: 58, height: 58)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(die.isHeld ? AppTheme.coral : .white.opacity(0.5), lineWidth: die.isHeld ? 3 : 1)
        }
        .rotationEffect(.degrees(isRolling ? spin : 0))
        .offset(y: isRolling ? -6 : 0)
        .animation(.easeInOut(duration: 0.08).repeatCount(6, autoreverses: true), value: isRolling)
        .onChange(of: isRolling) { _, rolling in
            if rolling {
                spin = Double.random(in: -18...18)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    spin = 0
                }
            }
        }
    }
}

struct DiePips: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let inset = s * 0.22
            let positions = pipPositions(for: value)

            ZStack {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .frame(width: s * 0.16, height: s * 0.16)
                        .position(
                            x: inset + point.x * (s - inset * 2),
                            y: inset + point.y * (s - inset * 2)
                        )
                }
            }
        }
        .padding(6)
    }

    private func pipPositions(for value: Int) -> [CGPoint] {
        switch value {
        case 1: return [.init(x: 0.5, y: 0.5)]
        case 2: return [.init(x: 0.18, y: 0.18), .init(x: 0.82, y: 0.82)]
        case 3: return [.init(x: 0.18, y: 0.18), .init(x: 0.5, y: 0.5), .init(x: 0.82, y: 0.82)]
        case 4: return [
            .init(x: 0.18, y: 0.18), .init(x: 0.82, y: 0.18),
            .init(x: 0.18, y: 0.82), .init(x: 0.82, y: 0.82)
        ]
        case 5: return [
            .init(x: 0.18, y: 0.18), .init(x: 0.82, y: 0.18),
            .init(x: 0.5, y: 0.5),
            .init(x: 0.18, y: 0.82), .init(x: 0.82, y: 0.82)
        ]
        default: return [
            .init(x: 0.18, y: 0.18), .init(x: 0.82, y: 0.18),
            .init(x: 0.18, y: 0.5), .init(x: 0.82, y: 0.5),
            .init(x: 0.18, y: 0.82), .init(x: 0.82, y: 0.82)
        ]
        }
    }
}
