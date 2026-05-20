import SwiftUI

/// Inline min/sec wheel picker that slides in below a `ValuePickerRow` when
/// expanded. Live binding — changes apply immediately. Mirrors Apple's
/// Calendar accordion pattern (tap row → wheel reveals, tap again → collapses).
struct InlineTimeWheel: View {
    @Binding var seconds: Int
    let minSeconds: Int
    let maxSeconds: Int

    @State private var minutes: Int
    @State private var secs: Int

    init(seconds: Binding<Int>, minSeconds: Int, maxSeconds: Int) {
        self._seconds = seconds
        self.minSeconds = minSeconds
        self.maxSeconds = maxSeconds
        self._minutes = State(initialValue: seconds.wrappedValue / 60)
        self._secs = State(initialValue: seconds.wrappedValue % 60)
    }

    var body: some View {
        HStack(spacing: 0) {
            wheel(label: "min", range: 0...60, selection: $minutes)
            wheel(label: "sec", range: 0...59, selection: $secs)
        }
        .frame(height: 160)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onChange(of: minutes) { _, _ in writeBack() }
        .onChange(of: secs) { _, _ in writeBack() }
        .onChange(of: seconds) { _, new in
            // External writes (e.g. preset selection) should sync the wheels.
            let nextMin = new / 60
            let nextSec = new % 60
            if minutes != nextMin { minutes = nextMin }
            if secs != nextSec   { secs = nextSec }
        }
    }

    private func wheel(label: LocalizedStringKey, range: ClosedRange<Int>, selection: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Picker(label, selection: selection) {
                ForEach(range, id: \.self) { v in
                    Text(v, format: .number.precision(.integerLength(2...)))
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Text(label)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func writeBack() {
        seconds = min(max(minutes * 60 + secs, minSeconds), maxSeconds)
    }
}
