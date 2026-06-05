import SwiftUI

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
                ZStack {
                    Circle()
                        .fill(AppTheme.coral.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .foregroundStyle(AppTheme.coral)
                }
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
                ZStack {
                    Circle()
                        .fill(AppTheme.coral.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(AppTheme.secondaryText)
                        .font(.callout.weight(.semibold))
                }
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
