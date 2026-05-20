import Foundation
import ActivityKit
import os

/// Thin wrapper around ActivityKit for the Interval Live Activity.
///
/// The TimerEngine calls into this on phase boundaries; we shield the engine
/// from the verbose ActivityKit API and from the ActivityAuthorizationInfo
/// flag. If the user has Live Activities disabled or we're on a device that
/// doesn't support them, every method is a silent no-op.
///
/// ## Race handling
///
/// Activity creation isn't truly instantaneous — `start()` first awaits
/// `endImmediately()` to tear down any stale prior activity, which is a real
/// ActivityKit IPC call (can take a few hundred ms). During that window the
/// engine has already started ticking and may have advanced phases. To avoid
/// dropping those updates, every state passed to start/update is also written
/// to `pendingState`; once `Activity.request` returns, we publish the *latest*
/// pending state, not whatever was queued at the start of the call.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<IntervalActivityAttributes>?
    /// Latest desired content state. Used to (1) reconcile after the async
    /// `Activity.request` resolves, and (2) replay updates that arrived
    /// before the activity existed.
    private var pendingState: IntervalActivityAttributes.ContentState?
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
        let initialState = IntervalActivityAttributes.ContentState(
            phase: phase,
            phaseStartDate: start,
            phaseEndDate: end,
            currentRound: round
        )
        pendingState = initialState

        // Await any in-flight teardown before requesting a new activity, so a
        // rapid stop/restart can't leave two activities competing.
        await endImmediately()

        // The engine may have called updatePhase() during the await above —
        // honour whichever state is newest.
        let stateToPublish = pendingState ?? initialState
        let attrs = IntervalActivityAttributes(
            workoutName: workoutName,
            totalRounds: totalRounds
        )
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: stateToPublish, staleDate: nil, relevanceScore: 100)
            )
            pendingState = nil
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
    ///
    /// If the activity hasn't finished being created yet, we stash the state
    /// in `pendingState` so `start()` picks it up when `Activity.request`
    /// resolves. No update is lost.
    func updatePhase(_ phase: ActivityPhase, round: Int, start: Date, end: Date) {
        let state = IntervalActivityAttributes.ContentState(
            phase: phase,
            phaseStartDate: start,
            phaseEndDate: end,
            currentRound: round
        )
        if let activity {
            Task {
                await activity.update(
                    .init(state: state, staleDate: nil, relevanceScore: 100)
                )
            }
        } else {
            // Activity creation still in flight. Queue the latest state.
            pendingState = state
        }
    }

    func finish(round: Int) {
        guard let activity else { return }
        // Disown the property *before* the async dismissal so a subsequent
        // start() sees a clean slate even if the previous activity is still
        // mid-dismiss-after-N-seconds.
        self.activity = nil
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
        }
    }

    func endImmediately() async {
        guard let activity else { return }
        self.activity = nil
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }
}
