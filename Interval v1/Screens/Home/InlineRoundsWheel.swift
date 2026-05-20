import SwiftUI

/// Inline rounds wheel picker (1...99). Companion to `InlineTimeWheel` for the
/// accordion-style expansion pattern on the Home screen.
struct InlineRoundsWheel: View {
    @Binding var rounds: Int

    var body: some View {
        Picker("Rounds", selection: $rounds) {
            ForEach(1...99, id: \.self) { v in
                Text(verbatim: "\(v)")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .tag(v)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 160)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
