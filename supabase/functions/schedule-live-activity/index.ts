// schedule-live-activity
// =================================================================
// Receives the upfront schedule of a workout from the iOS app and
// (re)populates the live_activity_pushes queue. Called every time the
// schedule needs to be rewritten — workout start, pause, resume, skip.
//
// Body shape (matches LiveActivityPushScheduler.ScheduleRequest in Swift):
//   {
//     token: string,                       // hex APNs activity token
//     bundleId: string,                    // e.g. com.superapp.intervalv1
//     attributes: { workoutName, totalRounds },
//     pushes: [
//       {
//         scheduledAt: number,             // Swift Date (sec since 2001)
//         event: "update" | "end",
//         state: {
//           phase: "countdown" | "work" | "rest" | "finished",
//           phaseStartDate: number,        // Swift Date
//           phaseEndDate: number,          // Swift Date
//           currentRound: number
//         }
//       },
//       ...
//     ]
//   }
// =================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

// Swift Date encodes as seconds since 2001-01-01 UTC.
// Unix epoch (1970-01-01) is 978307200 seconds before that.
const SWIFT_REFERENCE_OFFSET_SECONDS = 978307200;

function swiftDateToJSDate(swiftSeconds: number): Date {
    return new Date((swiftSeconds + SWIFT_REFERENCE_OFFSET_SECONDS) * 1000);
}

interface SchedulePushRequest {
    token: string;
    bundleId: string;
    attributes: {
        workoutName: string;
        totalRounds: number;
    };
    pushes: Array<{
        scheduledAt: number;
        event: "update" | "end";
        state: {
            phase: string;
            phaseStartDate: number;
            phaseEndDate: number;
            currentRound: number;
        };
    }>;
}

const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
);

Deno.serve(async (req) => {
    if (req.method !== "POST") {
        return new Response("Method not allowed", { status: 405 });
    }

    let body: SchedulePushRequest;
    try {
        body = await req.json();
    } catch {
        return new Response("Invalid JSON", { status: 400 });
    }

    if (!body.token || !body.bundleId || !Array.isArray(body.pushes)) {
        return new Response("Missing required fields", { status: 400 });
    }

    // 1. Drop any unsent pushes for this token so reschedules are clean.
    const { error: deleteErr } = await supabase
        .from("live_activity_pushes")
        .delete()
        .eq("token", body.token)
        .eq("sent", false);
    if (deleteErr) {
        console.error("delete failed:", deleteErr);
        return new Response(JSON.stringify({ error: deleteErr.message }), { status: 500 });
    }

    // 2. Build the rows. Each row's `payload` is the FULL APNs payload that
    //    `send-due-live-activity-pushes` will POST as-is — pre-shaped here
    //    so the dispatcher is dumb.
    const rows = body.pushes.map((p) => {
        const scheduledJS = swiftDateToJSDate(p.scheduledAt);
        const aps: Record<string, unknown> = {
            timestamp: Math.floor(scheduledJS.getTime() / 1000),
            event: p.event,
            "content-state": p.state,
            "relevance-score": 100,
        };
        if (p.event === "end") {
            // Stay visible briefly after the final push, then dismiss.
            aps["dismissal-date"] = Math.floor(scheduledJS.getTime() / 1000) + 8;
        }
        return {
            token: body.token,
            bundle_id: body.bundleId,
            scheduled_at: scheduledJS.toISOString(),
            event: p.event,
            payload: { aps },
        };
    });

    const { error: insertErr } = await supabase
        .from("live_activity_pushes")
        .insert(rows);
    if (insertErr) {
        console.error("insert failed:", insertErr);
        return new Response(JSON.stringify({ error: insertErr.message }), { status: 500 });
    }

    return new Response(
        JSON.stringify({ scheduled: rows.length }),
        { headers: { "Content-Type": "application/json" } }
    );
});
