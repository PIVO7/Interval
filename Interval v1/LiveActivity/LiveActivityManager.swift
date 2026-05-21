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
/// ## Push-based updates
///
/// As of this build the activity is created with `pushType: .token` so the
/// system can deliver remote updates via APNs even when the app is fully
/// suspended (the device is locked + no audio is playing). The token is
/// observed via `Activity.pushTokenUpdates` and forwarded to Supabase along
/// with the complete workout schedule. From that moment on, phase
/// transitions arrive as pushes, not via local `Activity.update(...)` calls.
///
/// Local `updatePhase(...)` is kept for pause/skip moments where the engine
/// itself recomputes and pushes a fresh state to the system immediately —
/// the queued remote pushes for the rest of the workout are then replaced
/// by a re-schedule.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<IntervalActivityAttributes>?
    /// Hex-encoded APNs token for the currently-active activity, observed
    /// from `Activity.pushTokenUpdates`. Used by re-schedule / cancel calls.
    private var currentPushToken: String?
    /// Latest desired content state. Used to (1) reconcile after the async
    /// `Activity.request` resolves, and (2) replay updates that arrived
    /// before the activity existed.
    private var pendingState: IntervalActivityAttributes.ContentState?
    /// Background task that listens for push-token updates from ActivityKit.
    /// Cancelled when the activity ends.
    private var pushTokenObservation: Task<Void, Never>?

    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "LiveActivity")

    private var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {}

    // MARK: - Lifecycle

    /// Start a Live Activity for a workout, request a push token, and
    /// forward the complete workout schedule to Supabase so remote pushes
    /// can drive subsequent phase transitions even when the app is asleep.
    func start(
        workoutName: String,
        totalRounds: Int,
        phase: ActivityPhase,
        round: Int,
        start: Date,
        end: Date,
        workout: Workout
    ) async {
        guard isEnabled else { return }
        let initialState = IntervalActivityAttributes.ContentState(
            phase: phase,
            phaseStartDate: start,
            phaseEndDate: end,
            currentRound: round
        )
        pendingState = initialState

        // Await any in-flight teardown before requesting a new activity, so
        // a rapid stop/restart can't leave two activities competing.
        await endImmediately()

        let stateToPublish = pendingState ?? initialState
        let attrs = IntervalActivityAttributes(
            workoutName: workoutName,
            totalRounds: totalRounds
        )
        do {
            let newActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: stateToPublish, staleDate: nil, relevanceScore: 100),
                pushType: .token
            )
            activity = newActivity
            pendingState = nil
            observePushToken(for: newActivity, attributes: attrs, workout: workout)
        } catch {
            log.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Local push for cases where the engine itself needs to publish a
    /// fresh state immediately (pause, resume, skip). After this, any
    /// queued remote pushes that would conflict need to be re-scheduled.
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
            // Activity creation still in flight.
            pendingState = state
        }
    }

    /// Re-publish the entire remaining workout schedule to Supabase. Call
    /// after a pause/resume/skip to keep the remote queue consistent with
    /// the engine's wall-clock state.
    func reschedulePushes(workout: Workout, from now: Date) async {
        guard let token = currentPushToken, let attributes = activity?.attributes else { return }
        let pushes = workout.liveActivitySchedule(startingAt: now)
        await LiveActivityPushScheduler.shared.schedule(
            token: token,
            attributes: attributes,
            pushes: pushes
        )
    }

    func finish(round: Int) {
        guard let activity else { return }
        let tokenToCancel = currentPushToken
        self.activity = nil
        currentPushToken = nil
        pushTokenObservation?.cancel()
        pushTokenObservation = nil

        let now = Date.now
        let state = IntervalActivityAttributes.ContentState(
            phase: .finished,
            phaseStartDate: now,
            phaseEndDate: now,
            currentRound: round
        )
        Task {
            // The push-driven schedule contains its own .end push. If it
            // hasn't fired yet (e.g. user finished early via skip), tell
            // Supabase to drop the rest.
            if let tokenToCancel {
                await LiveActivityPushScheduler.shared.cancel(token: tokenToCancel)
            }
            await activity.end(
                .init(state: state, staleDate: nil),
                dismissalPolicy: .after(now.addingTimeInterval(8))
            )
        }
    }

    func endImmediately() async {
        guard let activity else { return }
        let tokenToCancel = currentPushToken
        self.activity = nil
        currentPushToken = nil
        pushTokenObservation?.cancel()
        pushTokenObservation = nil

        if let tokenToCancel {
            await LiveActivityPushScheduler.shared.cancel(token: tokenToCancel)
        }
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }

    // MARK: - Push token observation

    /// Subscribes to `Activity.pushTokenUpdates`. The first emitted token
    /// triggers a full-workout schedule POST to Supabase. Subsequent token
    /// updates (rare — happens if iOS rotates the token) re-schedule with
    /// the wall-clock starting point so we stay current.
    private func observePushToken(
        for activity: Activity<IntervalActivityAttributes>,
        attributes: IntervalActivityAttributes,
        workout: Workout
    ) {
        pushTokenObservation?.cancel()
        let workoutStart = Date.now
        pushTokenObservation = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                guard let self else { return }
                let isFirstToken = (self.currentPushToken == nil)
                self.currentPushToken = hex
                let pushes = workout.liveActivitySchedule(
                    startingAt: isFirstToken ? workoutStart : Date.now
                )
                await LiveActivityPushScheduler.shared.schedule(
                    token: hex,
                    attributes: attributes,
                    pushes: pushes
                )
            }
        }
    }
}
