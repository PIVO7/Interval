import SwiftUI

struct CountdownView: View {
    let count: Int

    /// Massive "3 / 2 / 1 / GO" text scales with Dynamic Type so users on
    /// larger accessibility sizes still get the hero treatment.
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 20) {
            Text("Klaar voor de start?")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 200, height: 200)
                Group {
                    if count > 0 {
                        Text(verbatim: "\(count)")
                    } else {
                        Text("GO!")
                    }
                }
                .font(.system(size: countdownSize, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.appSmooth, value: count)
            }
            .scaleEffect(count > 0 ? 1 : 1.1)
            .animation(.appBounce, value: count)
            // VoiceOver: ensure each tick is announced even though the
            // change is purely visual (numericText transition). Without
            // `updatesFrequently` + a stable label the assistive layer
            // falls silent during the 3-2-1 countdown.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count > 0 ? Text("\(count)") : Text("Start"))
            .accessibilityAddTraits(.updatesFrequently)

            Text("Begin...")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [AppTheme.coral, AppTheme.coralDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        CountdownView(count: 3)
    }
}
