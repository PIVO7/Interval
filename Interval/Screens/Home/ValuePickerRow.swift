import SwiftUI

/// Compact tappable row showing label + current value, used inside a softCard
/// container with `InlineTimeWheel` / `InlineRoundsWheel` for a Calendar-style
/// accordion.
///
/// Affordances:
/// - Value text is always rendered in `tint` colour to signal interactivity
///   (vs. Apple Calendar which uses grey — we deviate here because the row is
///   not in a system form context, so it needs to read as a button)
/// - When expanded (`isSelected`), the value gains a subtle pill background in
///   the tint colour, mirroring DatePicker `.compact` chips
/// - Custom `RowButtonStyle` adds a press-down highlight so the whole row
///   reads as a tap target
struct ValuePickerRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let value: String
    let isSelected: Bool
    /// One-shot "this is tappable" pulse on the value chip. Used for first-launch
    /// onboarding nudge. Defaults to false.
    var isNudging: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isSelected ? 0.28 : 0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .font(.callout)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                valueChip
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(tint.opacity(isSelected ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }

    private var valueChip: some View {
        Text(verbatim: value)
            .font(.system(.body, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(tint.opacity(chipOpacity))
            )
            .scaleEffect(isNudging ? 1.10 : 1.0)
            // No `isSelected` animation here on purpose — the chip
            // background change inherits the parent's accordion animation
            // so the chip pill, the row tint, and the wheel all finish
            // in sync. Bounce stays for the first-launch nudge only.
            .animation(.appBounce, value: isNudging)
    }

    private var chipOpacity: Double {
        if isNudging { return 0.32 }
        return isSelected ? 0.22 : 0.12
    }
}

/// Press-down highlight + subtle scale so tapping feels tactile. Tuned fast
/// (0.12s) so the response feels immediate rather than alive.
private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
