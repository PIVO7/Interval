// cancel-live-activity
// =================================================================
// Drops every unsent push from the queue for the given activity token.
// Called by the app when a workout is stopped or the activity ends
// before its scheduled finish.
// =================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

interface CancelRequest {
    token: string;
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
    let body: CancelRequest;
    try {
        body = await req.json();
    } catch {
        return new Response("Invalid JSON", { status: 400 });
    }
    if (!body.token) {
        return new Response("Missing token", { status: 400 });
    }

    const { data, error } = await supabase
        .from("live_activity_pushes")
        .delete()
        .eq("token", body.token)
        .eq("sent", false)
        .select("id");
    if (error) {
        console.error("delete failed:", error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
    return new Response(
        JSON.stringify({ cancelled: data?.length ?? 0 }),
        { headers: { "Content-Type": "application/json" } }
    );
});
