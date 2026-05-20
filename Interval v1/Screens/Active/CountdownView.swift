import SwiftUI

struct CountdownView: View {
    let count: Int

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
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.appSmooth, value: count)
            }
            .scaleEffect(count > 0 ? 1 : 1.1)
            .animation(.appBounce, value: count)

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
