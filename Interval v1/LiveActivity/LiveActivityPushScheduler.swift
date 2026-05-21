import Foundation
import os

/// Forwards the upfront workout schedule + APNs activity token to the
/// Supabase Edge Function that queues remote pushes.
///
/// The app calls `schedule(...)` once at workout start, then `cancel(...)`
/// if the user stops early. Re-scheduling (after pause / skip) is also done
/// via `schedule(...)` — the Edge Function replaces existing pushes for
/// the same token.
@MainActor
final class LiveActivityPushScheduler {
    static let shared = LiveActivityPushScheduler()

    private let log = Logger(subsystem: "com.superapp.intervalv1", category: "PushScheduler")

    private init() {}

    /// Sent to the `schedule-live-activity` Edge Function.
    private struct ScheduleRequest: Codable {
        let token: String
        let bundleId: String
        let attributes: IntervalActivityAttributes
        let pushes: [ScheduledLiveActivityPush]
    }

    /// Sent to the `cancel-live-activity` Edge Function.
    private struct CancelRequest: Codable {
        let token: String
    }

    /// Schedule a full workout's worth of remote pushes. The Edge Function
    /// inserts queued rows into the `live_activity_pushes` table; pg_cron
    /// picks them up and dispatches to APNs at the right time.
    func schedule(
        token: String,
        attributes: IntervalActivityAttributes,
        pushes: [ScheduledLiveActivityPush]
    ) async {
        guard SupabaseConfig.isConfigured else {
            log.info("Supabase not configured — skipping remote push schedule.")
            return
        }
        let body = ScheduleRequest(
            token: token,
            bundleId: Bundle.main.bundleIdentifier ?? "com.superapp.intervalv1",
            attributes: attributes,
            pushes: pushes
        )
        do {
            try await SupabaseManager.shared.client.functions.invoke(
                "schedule-live-activity",
                options: .init(body: body)
            )
            log.info("Scheduled \(pushes.count, privacy: .public) Live Activity pushes")
        } catch {
            log.error("schedule-live-activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Cancel all queued pushes for the given activity token (used when the
    /// user stops a workout before it ends).
    func cancel(token: String) async {
        guard SupabaseConfig.isConfigured else { return }
        let body = CancelRequest(token: token)
        do {
            try await SupabaseManager.shared.client.functions.invoke(
                "cancel-live-activity",
                options: .init(body: body)
            )
            log.info("Cancelled queued Live Activity pushes")
        } catch {
            log.error("cancel-live-activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
