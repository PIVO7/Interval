import SwiftUI
import SwiftData

/// One row in the Favorites list. Split into THREE zones with clearly
/// distinct affordances:
///   - Play circle (left, coral, 44pt tap target) → starts the workout.
///   - Descriptive text (middle) → read-only display, NOT tappable.
///   - Adjust icon (right, neutral, 44pt tap target) → opens the edit sheet.
/// Swipe-to-delete is handled by the parent List; an `accessibilityAction`
/// on the row exposes the same destructive action to VoiceOver.
struct FavoriteRowView: View {
    let entity: WorkoutEntity
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .foregroundStyle(AppTheme.coral)
                    .modifier(GlassControlCircle(
                        tint: AppTheme.coral.opacity(0.15),
                        diameter: 44
                    ))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(entity.name)")

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(entity.summary)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(AppTheme.secondaryText)
                    .font(.callout.weight(.semibold))
                    .modifier(GlassControlCircle(
                        tint: AppTheme.coral.opacity(0.08),
                        diameter: 36
                    ))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bewerk \(entity.name)")
        }
        .padding(16)
        .softCard()
    }
}

/// iOS 26+: the row's round controls sit on interactive Liquid Glass, so the
/// two tappable zones read as raised controls against the flat card. Earlier
/// systems keep the original flat tinted circle — same size, no layout shift.
private struct GlassControlCircle: ViewModifier {
    let tint: Color
    let diameter: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
            content
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(tint))
        }
    }
}
