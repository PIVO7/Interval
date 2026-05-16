import SwiftUI

struct CountdownView: View {
    let count: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("Klaar voor de start?")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 200)
                Text(count > 0 ? "\(count)" : "GO!")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
            }
            .scaleEffect(count > 0 ? 1 : 1.1)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: count)

            Text("Begin...")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [AppTheme.coral, AppTheme.amber],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        CountdownView(count: 3)
    }
}
