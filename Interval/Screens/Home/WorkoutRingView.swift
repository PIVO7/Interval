import SwiftUI

/// The workout drawn as a ring: one coral arc per work interval and one sage
/// arc per rest, proportional to their duration and in the order they will
/// play. Turns the three numbers below it into a shape you can read at a
/// glance — "lots of short rests" or "long blocks" looks different — and
/// fills the hero area on iPad instead of a lone number in a wide card.
///
/// Mirrors `Workout.totalSeconds`: no rest after the final round.
struct WorkoutRingView<Center: View>: View {
    let workSeconds: Int
    let restSeconds: Int
    let rounds: Int
    var lineWidth: CGFloat = 16
    @ViewBuilder var center: Center

    private struct Segment: Identifiable {
        let id: Int
        let start: Double
        let end: Double
        let isWork: Bool
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.secondaryText.opacity(0.12), lineWidth: lineWidth)

            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.isWork ? AppTheme.coral : AppTheme.sage,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            center
                .padding(lineWidth + 12)
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .animation(.appSmooth, value: [workSeconds, restSeconds, rounds])
    }

    private var segments: [Segment] {
        let rounds = max(1, rounds)
        let work = max(0, workSeconds)
        let rest = max(0, restSeconds)
        let total = Double(rounds * work + (rounds - 1) * rest)
        guard total > 0 else { return [] }

        let count = rest > 0 ? rounds * 2 - 1 : rounds
        // Hairline gaps separate the intervals; past ~80 arcs they would eat
        // the whole ring, so very long workouts draw as a continuous band.
        let gap = count > 1 && count <= 80 ? 0.006 : 0

        var result: [Segment] = []
        result.reserveCapacity(count)
        var cursor = 0.0

        func append(_ seconds: Int, isWork: Bool) {
            let length = Double(seconds) / total
            let start = cursor + gap / 2
            let end = max(start, cursor + length - gap / 2)
            result.append(Segment(id: result.count, start: start, end: end, isWork: isWork))
            cursor += length
        }

        for round in 0..<rounds {
            append(work, isWork: true)
            if round < rounds - 1 && rest > 0 {
                append(rest, isWork: false)
            }
        }
        return result
    }
}

#Preview {
    WorkoutRingView(workSeconds: 30, restSeconds: 15, rounds: 8, lineWidth: 18) {
        Text(verbatim: "5m 45s")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
    }
    .frame(width: 280)
    .padding()
}
