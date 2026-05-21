import Foundation

/// One scheduled remote push to ActivityKit for a Live Activity update.
///
/// The app computes the *entire* workout's schedule upfront when a workout
/// starts and POSTs it to Supabase. From that moment on, the app itself no
/// longer needs to be alive — Supabase fires each push at its `scheduledAt`
/// timestamp and APNs delivers the new ContentState to the activity.
struct ScheduledLiveActivityPush: Codable, Sendable {
    /// When Supabase should send the push to APNs. Absolute UTC timestamp.
    let scheduledAt: Date
    /// The phase the activity should transition to. `update` for ongoing
    /// phases, `end` for the final "finished" state which dismisses.
    let event: Event
    /// ContentState shipped inside the APNs payload.
    let state: IntervalActivityAttributes.ContentState

    enum Event: String, Codable, Sendable {
        case update
        case end
    }
}

extension Workout {
    /// Produces the full timeline of Live Activity pushes for one workout,
    /// starting at `now`. Mirrors TimerEngine's phase-advancement logic:
    /// countdown → work → (rest → work → …) → finished. Rest is omitted
    /// after the final round, matching `Workout.totalSeconds`.
    func liveActivitySchedule(
        startingAt now: Date,
        countdownSeconds: Int = 3
    ) -> [ScheduledLiveActivityPush] {
        var pushes: [ScheduledLiveActivityPush] = []
        var phaseStart = now

        // Round 1 work begins after the countdown.
        let workStart1 = now.addingTimeInterval(TimeInterval(countdownSeconds))
        pushes.append(.init(
            scheduledAt: workStart1,
            event: .update,
            state: .init(
                phase: .work,
                phaseStartDate: workStart1,
                phaseEndDate: workStart1.addingTimeInterval(TimeInterval(workSeconds)),
                currentRound: 1
            )
        ))
        phaseStart = workStart1.addingTimeInterval(TimeInterval(workSeconds))

        for round in 1...rounds {
            let isLastRound = (round == rounds)
            let willHaveRest = !isLastRound && restSeconds > 0

            if willHaveRest {
                // Rest after this round's work.
                let restEnd = phaseStart.addingTimeInterval(TimeInterval(restSeconds))
                pushes.append(.init(
                    scheduledAt: phaseStart,
                    event: .update,
                    state: .init(
                        phase: .rest,
                        phaseStartDate: phaseStart,
                        phaseEndDate: restEnd,
                        currentRound: round
                    )
                ))
                phaseStart = restEnd

                // Next round's work.
                let workEnd = phaseStart.addingTimeInterval(TimeInterval(workSeconds))
                pushes.append(.init(
                    scheduledAt: phaseStart,
                    event: .update,
                    state: .init(
                        phase: .work,
                        phaseStartDate: phaseStart,
                        phaseEndDate: workEnd,
                        currentRound: round + 1
                    )
                ))
                phaseStart = workEnd
            }
        }

        // Final "finished" push ends the activity.
        pushes.append(.init(
            scheduledAt: phaseStart,
            event: .end,
            state: .init(
                phase: .finished,
                phaseStartDate: phaseStart,
                phaseEndDate: phaseStart,
                currentRound: rounds
            )
        ))

        return pushes
    }
}
