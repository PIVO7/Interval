import SwiftUI

struct RoundsCard: View {
    @Binding var rounds: Int
    private let minRounds = 1
    private let maxRounds = 99

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.amber.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: "repeat")
                    .foregroundStyle(AppTheme.amber)
                    .font(.callout)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Rounds")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Aantal ronden")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            HStack(spacing: 12) {
                stepButton(systemName: "minus", enabled: rounds > minRounds) {
                    if rounds > minRounds { rounds -= 1 }
                }
                Text("\(rounds)")
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(minWidth: 36)
                stepButton(systemName: "plus", enabled: rounds < maxRounds) {
                    if rounds < maxRounds { rounds += 1 }
                }
            }
        }
        .padding(20)
        .softCard()
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(.headline, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(AppTheme.coral.opacity(enabled ? 0.15 : 0.06))
                )
                .foregroundStyle(enabled ? AppTheme.coral : AppTheme.secondaryText)
        }
        .disabled(!enabled)
        .accessibilityLabel(systemName == "plus" ? "Verhoog ronden" : "Verlaag ronden")
    }
}
