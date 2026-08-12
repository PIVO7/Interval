import SwiftUI

/// Inline min/sec wheel picker that slides in below a `ValuePickerRow` when
/// expanded. Live binding — changes apply immediately. Mirrors Apple's
/// Calendar accordion pattern (tap row → wheel reveals, tap again → collapses).
///
/// Both wheels derive directly from the `seconds` binding via computed
/// bindings rather than caching into local `@State`. That keeps a single
/// source of truth — external writes (preset selection, defaults) reflect
/// instantly, and there's no mirror state to keep in sync or oscillate.
struct InlineTimeWheel: View {
    @Binding var seconds: Int
    let minSeconds: Int
    let maxSeconds: Int

    /// The stored value, clamped into the representable range so it always
    /// decomposes to a valid wheel position.
    private var clamped: Int { min(max(seconds, minSeconds), maxSeconds) }

    /// Largest minute value the user can pick — derived from `maxSeconds`
    /// rather than hard-coded so callers can constrain the range.
    private var maxMinutes: Int { maxSeconds / 60 }

    /// Seconds wheel collapses to "0" once minutes is at the cap.
    /// Without this, picking `maxMinutes:59` (e.g. 60:59 against 3600)
    /// would silently clamp back to maxSeconds — confusing because the
    /// wheel position doesn't snap visibly.
    private var availableSecondsRange: ClosedRange<Int> {
        clamped / 60 >= maxMinutes ? 0...0 : 0...59
    }

    private var minutesBinding: Binding<Int> {
        Binding { clamped / 60 } set: { write(minutes: $0, secs: clamped % 60) }
    }

    private var secsBinding: Binding<Int> {
        Binding { clamped % 60 } set: { write(minutes: clamped / 60, secs: $0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            wheel(label: "min", range: 0...maxMinutes, selection: minutesBinding)
            wheel(label: "sec", range: availableSecondsRange, selection: secsBinding)
        }
        .frame(height: 160)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Recompose minutes + seconds into the stored value, clamped into
    /// range. When minutes hits the cap, force seconds to 0 so the value
    /// doesn't silently clamp against maxSeconds while the wheel shows a
    /// non-zero position.
    private func write(minutes: Int, secs: Int) {
        let effectiveSecs = minutes >= maxMinutes ? 0 : secs
        let raw = minutes * 60 + effectiveSecs
        seconds = min(max(raw, minSeconds), maxSeconds)
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
}
