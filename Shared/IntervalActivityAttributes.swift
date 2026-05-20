import ActivityKit
import Foundation

/// Data passed from the app into the Live Activity widget.
///
/// The clever bit: we store `phaseEndDate` (a `Date`) instead of remaining
/// seconds. The widget can then use `Text(timerInterval:countsDown:)` and
/// `ProgressView(timerInterval:countsDown:)` which auto-tick locally without
/// the app having to push an update every second. The app only needs to call
/// `Activity.update(...)` at phase boundaries (work → rest → next round).
public struct IntervalActivityAttributes: ActivityAttributes, Sendable {

    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: ActivityPhase
        public var phaseStartDate: Date
        public var phaseEndDate: Date
        public var currentRound: Int

        public init(
            phase: ActivityPhase,
            phaseStartDate: Date,
            phaseEndDate: Date,
            currentRound: Int
        ) {
            self.phase = phase
            self.phaseStartDate = phaseStartDate
            self.phaseEndDate = phaseEndDate
            self.currentRound = currentRound
        }
    }

    public var workoutName: String
    public var totalRounds: Int

    public init(workoutName: String, totalRounds: Int) {
        self.workoutName = workoutName
        self.totalRounds = totalRounds
    }
}
