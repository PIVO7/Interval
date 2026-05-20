import ActivityKit
import WidgetKit
import SwiftUI

struct IntervalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntervalActivityAttributes.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.12))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.phase.symbol)
                            .foregroundStyle(context.state.phase.tint)
                        Text(context.state.phase.label)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(context.state.phase.tint)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(verbatim: "Ronde \(context.state.currentRound) / \(context.attributes.totalRounds)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(state: context.state, attributes: context.attributes)
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
            } compactTrailing: {
                if context.state.phase != .finished {
                    Text(timerInterval: Date.now...context.state.phaseEndDate,
                         countsDown: true,
                         showsHours: false)
                        .monospacedDigit()
                        .frame(maxWidth: 56)
                        .foregroundStyle(context.state.phase.tint)
                } else {
                    Image(systemName: "checkmark")
                        .foregroundStyle(WidgetBrand.sageDeep)
                }
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
            }
            .widgetURL(DeepLink.active)
            .keylineTint(context.state.phase.tint)
        }
    }

    private func expandedBottom(
        state: IntervalActivityAttributes.ContentState,
        attributes: IntervalActivityAttributes
    ) -> some View {
        VStack(spacing: 10) {
            if state.phase != .finished {
                HStack(alignment: .firstTextBaseline) {
                    Text(timerInterval: Date.now...state.phaseEndDate,
                         countsDown: true,
                         showsHours: false)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(verbatim: attributes.workoutName)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ProgressView(timerInterval: state.phaseStartDate...state.phaseEndDate,
                             countsDown: true)
                    .tint(state.phase.tint)
            } else {
                HStack {
                    Text("Training voltooid")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(WidgetBrand.amber)
                }
            }
        }
    }
}

private enum DeepLink {
    static let active = URL(string: "interval://active")
}
