import Foundation
import WorkoutKit
import HealthKit

// ⚠️ DEFERRED FEATURE — not shipped in 1.0
// =========================================
// This file is fully implemented and compiles, but `WorkoutKitExporter` is
// not referenced from any UI surface — no "Stuur naar Apple Watch" button
// exists yet. The conversion + WorkoutScheduler hand-off is ready to go;
// activating it requires the steps in the doc-comment below (HealthKit
// capability, Info.plist usage descriptions, and a tap target somewhere
// like FavoritesView or HomeView).
//
// We're keeping the code in tree so the WorkoutKit conversion stays unit-
// tested (WorkoutKitExporterTests) and so the next iteration can wire it
// up without reimplementing. If a future release decides not to ship the
// watch hand-off at all, delete this file + its tests + the WorkoutKit
// import to reduce review surface and avoid carrying a half-feature.

/// Converts our `Workout` into a WorkoutKit `CustomWorkout` and pushes it to
/// the user's paired Apple Watch via `WorkoutScheduler`. The watch's built-in
/// Workout app then handles timing, heart-rate, calories, and Fitness rings —
/// all of that comes "for free" once we hand the workout off to Apple.
///
/// ## Not yet wired into the UI
/// This file compiles and the conversion logic is ready. To **activate** the
/// "send to Apple Watch" flow:
///
/// 1. **Apple Developer Program** ($99/yr). HealthKit capability is unreliable
///    on Free Personal Teams.
/// 2. In Xcode, target **Interval v1** → tab **Signing & Capabilities** →
///    `+ Capability` → **HealthKit**.
/// 3. Add to `Info.plist` (or `project.yml` properties):
///    - `NSHealthShareUsageDescription` → "Interval gebruikt Apple Health om
///      je intervaltrainingen naar je Apple Watch te sturen."
///    - `NSHealthUpdateUsageDescription` → "Interval slaat voltooide trainingen
///      op in Apple Health."
/// 4. Add a button to UI (Favorieten rij of Home actionButtons):
///    ```
///    Button("Verzend naar Apple Watch") {
///        Task { try? await WorkoutKitExporter.shared.pushToWatch(workout) }
///    }
///    ```
/// 5. Show a toast / haptic on success: "Workout staat klaar op je horloge".
///
/// ## End-user flow once wired
/// 1. Tap "Verzend naar Apple Watch" in the app
/// 2. (First time) iOS asks permission for Workout scheduling — Allow
/// 3. On Apple Watch: open **Workout-app** → see the custom workout at the top
/// 4. Tap to start — Apple handles countdown, intervals, heart rate, summary
@MainActor
final class WorkoutKitExporter {
    static let shared = WorkoutKitExporter()
    private init() {}

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Toegang tot Apple Workout-functionaliteit geweigerd. Sta toe via Instellingen."
            }
        }
    }

    // MARK: - Public API

    /// Push the workout to the user's connected Apple Watch. Asks for
    /// authorization on first call.
    func pushToWatch(_ workout: Workout) async throws {
        try await ensureAuthorized()

        let plan = WorkoutPlan(.custom(makeCustomWorkout(from: workout)))
        let nowComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: .now
        )

        // `schedule(_:at:)` is async but non-throwing on iOS 18 — the framework
        // surfaces errors as state changes rather than thrown exceptions.
        await WorkoutScheduler.shared.schedule(plan, at: nowComponents)
    }

    /// Convert a `Workout` into a WorkoutKit `CustomWorkout`. Exposed so
    /// callers can preview the structure and so it can be unit-tested without
    /// HealthKit authorization.
    ///
    /// **Trailing-rest rule**: WorkoutKit's `IntervalBlock` with N iterations
    /// of `[work, recovery]` produces N work + N recovery, including a final
    /// trailing rest. Our timer model deliberately omits that (rest only
    /// *between* rounds — see `Workout.totalSeconds`). To match, we split into
    /// two blocks when `rounds > 1 && restSeconds > 0`: first `rounds - 1`
    /// iterations of `[work, recovery]`, then 1 iteration of `[work]` alone.
    func makeCustomWorkout(from workout: Workout) -> CustomWorkout {
        let workStep = WorkoutStep(
            goal: .time(Double(workout.workSeconds), .seconds),
            displayName: NSLocalizedString(
                "Inspanning",
                comment: "WorkoutKit step display name for work intervals"
            )
        )

        var blocks: [IntervalBlock] = []

        if workout.restSeconds == 0 || workout.rounds == 1 {
            // No rest at all, or single round — recovery step is meaningless.
            blocks.append(IntervalBlock(
                steps: [IntervalStep(.work, step: workStep)],
                iterations: workout.rounds
            ))
        } else {
            let restStep = WorkoutStep(
                goal: .time(Double(workout.restSeconds), .seconds),
                displayName: NSLocalizedString(
                    "Rust",
                    comment: "WorkoutKit step display name for rest intervals"
                )
            )
            // First N-1 rounds: alternating work + recovery
            blocks.append(IntervalBlock(
                steps: [
                    IntervalStep(.work, step: workStep),
                    IntervalStep(.recovery, step: restStep),
                ],
                iterations: workout.rounds - 1
            ))
            // Final round: work only, no trailing rest (matches our TimerEngine)
            blocks.append(IntervalBlock(
                steps: [IntervalStep(.work, step: workStep)],
                iterations: 1
            ))
        }

        return CustomWorkout(
            activity: .highIntensityIntervalTraining,
            location: .indoor,
            displayName: workout.name,
            blocks: blocks
        )
    }

    // MARK: - Authorization

    private func ensureAuthorized() async throws {
        let state = await WorkoutScheduler.shared.authorizationState
        switch state {
        case .authorized:
            return
        case .notDetermined:
            // `requestAuthorization()` returns the new AuthorizationState —
            // capture and discard since we re-read it below anyway.
            _ = await WorkoutScheduler.shared.requestAuthorization()
            let newState = await WorkoutScheduler.shared.authorizationState
            guard newState == .authorized else {
                throw ExportError.authorizationDenied
            }
        default:
            // .denied, .restricted, and any future cases all mean "no go".
            throw ExportError.authorizationDenied
        }
    }
}
