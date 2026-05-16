import SwiftUI

struct TimePickerCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var seconds: Int
    let minSeconds: Int
    let maxSeconds: Int

    private var minutes: Int { seconds / 60 }
    private var secs: Int { seconds % 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(spacing: 0) {
                wheel(
                    label: "min",
                    range: 0...60,
                    selection: Binding(
                        get: { minutes },
                        set: { newMin in
                            update(minutes: newMin, seconds: secs)
                        }
                    )
                )
                wheel(
                    label: "sec",
                    range: 0...59,
                    selection: Binding(
                        get: { secs },
                        set: { newSec in
                            update(minutes: minutes, seconds: newSec)
                        }
                    )
                )
            }
            .frame(height: 130)
        }
        .padding(20)
        .softCard()
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: systemImage).foregroundStyle(tint).font(.callout)
            }
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(displayValue)
                .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(tint)
        }
    }

    private var displayValue: String {
        String(format: "%02d:%02d", minutes, secs)
    }

    @ViewBuilder
    private func wheel(label: String, range: ClosedRange<Int>, selection: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Picker(label, selection: selection) {
                ForEach(range, id: \.self) { v in
                    Text(String(format: "%02d", v))
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func update(minutes m: Int, seconds s: Int) {
        var total = m * 60 + s
        total = min(max(total, minSeconds), maxSeconds)
        seconds = total
    }
}
