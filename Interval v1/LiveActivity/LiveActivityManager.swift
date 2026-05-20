import Foundation
import ActivityKit
import os

/// Thin wrapper around ActivityKit for the Interval Live Activity.
///
/// The TimerEngine calls into this on phase boundaries; we shield the engine
/// from the verbose ActivityKit API and from the ActivityAuthorizationInfo
/// flag. If the user has Live Activities disabled or we're on a device that
/// doesn't support them, every method is a silent no-op.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<IntervalActivityAttributes>?
    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "LiveActivity")

    private var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {}

    // MARK: - Lifecycle

    func start(
        workoutName: String,
        totalRounds: Int,
        phase: ActivityPhase,
        round: Int,
        start: Date,
        end: Date
    ) async {
        guard isEnabled else { return }
        // Await any in-flight teardown before requesting a new activity, so a
        // rapid stop/restart can't leave two activities competing.
        await endImmediately()
        let attrs = IntervalActivityAttributes(
            workoutName: workoutName,
            totalRounds: totalRounds
        )
        let state = IntervalActivityAttributes.ContentState(
            phase: phase,
            phaseStartDate: start,
            phaseEndDate: end,
            currentRound: round
        )
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil, relevanceScore: 100)
            )
        } catch {
            log.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Pushes a new phase to the activity. The engine passes explicit
    /// start/end dates so a phase recovered from the wall clock after a
    /// background suspension keeps its true start time (needed for the
    /// ProgressView's timerInterval to render correct partial progress).
    ///
    /// staleDate is nil: the widget self-ticks via Text(timerInterval:),
    /// and we don't want a delayed background update to grey out the
    /// activity (which iOS does once the staleDate passes).
    ///
    /// relevanceScore 100: high priority — iOS uses this to decide which
    /// activity stays prioritized when budgets are tight.
    func updatePhase(_ phase: ActivityPhase, round: Int, start: Date, end: Date) {
        guard let activity else { return }
        let state = IntervalActivityAttributes.ContentState(
            phase: phase,
            phaseStartDate: start,
            phaseEndDate: end,
            currentRound: round
        )
        Task {
            await activity.update(
                .init(state: state, staleDate: nil, relevanceScore: 100)
            )
        }
    }

    func finish(round: Int) {
        guard let activity else { return }
        let now = Date.now
        let state = IntervalActivityAttributes.ContentState(
            phase: .finished,
            phaseStartDate: now,
            phaseEndDate: now,
            currentRound: round
        )
        Task {
            await activity.end(
                .init(state: state, staleDate: nil),
                // Keep visible briefly so the user sees the trophy state,
                // then auto-dismiss.
                dismissalPolicy: .after(now.addingTimeInterval(8))
            )
            self.activity = nil
        }
    }

    func endImmediately() async {
        guard let activity else { return }
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        self.activity = nil
    }
}
