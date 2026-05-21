// send-due-live-activity-pushes
// =================================================================
// Called by pg_cron (via the dispatch_due_live_activity_pushes SQL
// function + pg_net.http_post) whenever there are pending pushes
// that have come due. Atomically claims up to 50 rows, signs an
// APNs JWT, and posts each push to api.push.apple.com.
//
// Required environment / secrets:
//   APNS_TEAM_ID       — 10-char Apple Team ID (e.g. VB6FS3N78T)
//   APNS_KEY_ID        — 10-char APNs Auth Key ID (from developer portal)
//   APNS_AUTH_KEY      — full .p8 PEM contents, BEGIN PRIVATE KEY ... END
//   APNS_HOST          — optional; defaults to api.push.apple.com
//                        (use api.sandbox.push.apple.com for Xcode dev builds)
// =================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";
import * as jose from "https://deno.land/x/jose@v5.2.0/index.ts";

const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
);

const APNS_HOST = Deno.env.get("APNS_HOST") ?? "api.push.apple.com";

// ----- APNs JWT signing ---------------------------------------------
// Token-based auth: a JWT signed with the .p8 EC private key (ES256).
// Apple allows a JWT to be reused for up to one hour. We cache it in
// memory between Edge Function invocations when possible.

let cachedJWT: string | null = null;
let cachedJWTExpiresAt = 0;

async function getAPNSJWT(): Promise<string> {
    if (cachedJWT && Date.now() < cachedJWTExpiresAt) {
        return cachedJWT;
    }
    const teamId = Deno.env.get("APNS_TEAM_ID");
    const keyId = Deno.env.get("APNS_KEY_ID");
    const keyPem = Deno.env.get("APNS_AUTH_KEY");
    if (!teamId || !keyId || !keyPem) {
        throw new Error("APNs secrets not configured");
    }
    const privateKey = await jose.importPKCS8(keyPem, "ES256");
    const jwt = await new jose.SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: keyId })
        .setIssuer(teamId)
        .setIssuedAt()
        .sign(privateKey);
    cachedJWT = jwt;
    // Refresh after 50 minutes to stay well under Apple's 1-hour limit.
    cachedJWTExpiresAt = Date.now() + 50 * 60 * 1000;
    return jwt;
}

// ----- Single push delivery -----------------------------------------

interface QueueRow {
    id: string;
    token: string;
    bundle_id: string;
    event: "update" | "end";
    payload: unknown;
}

async function sendPush(row: QueueRow, jwt: string): Promise<{ ok: boolean; error?: string }> {
    const url = `https://${APNS_HOST}/3/device/${row.token}`;
    try {
        const response = await fetch(url, {
            method: "POST",
            headers: {
                authorization: `bearer ${jwt}`,
                "apns-topic": `${row.bundle_id}.push-type.liveactivity`,
                "apns-push-type": "liveactivity",
                "apns-priority": "10",
                "apns-expiration": "0",
                "content-type": "application/json",
            },
            body: JSON.stringify(row.payload),
        });
        if (response.ok) {
            return { ok: true };
        }
        const text = await response.text();
        return { ok: false, error: `APNs ${response.status}: ${text}` };
    } catch (err) {
        return { ok: false, error: String(err) };
    }
}

// ----- Main handler -------------------------------------------------

Deno.serve(async () => {
    // Claim a batch of due rows atomically (SELECT … FOR UPDATE SKIP LOCKED
    // under the hood — defined in the migration as claim_due_live_activity_pushes).
    const { data, error: claimErr } = await supabase
        .rpc("claim_due_live_activity_pushes", { batch_size: 50 })
        .returns<QueueRow[]>();

    if (claimErr) {
        console.error("claim failed:", claimErr);
        return new Response(JSON.stringify({ error: claimErr.message }), { status: 500 });
    }
    const rows = data ?? [];
    if (rows.length === 0) {
        return new Response(JSON.stringify({ processed: 0 }), {
            headers: { "Content-Type": "application/json" }
        });
    }

    let jwt: string;
    try {
        jwt = await getAPNSJWT();
    } catch (err) {
        console.error("JWT signing failed:", err);
        return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
    }

    // Fire all pushes in parallel.
    const results = await Promise.all(rows.map((row) => sendPush(row, jwt)));

    // Bulk-update success/failure. Successful rows get sent=true; failed
    // rows record last_error and stay unsent so they'll be retried on the
    // next dispatcher tick (subject to attempt_count growth).
    const succeededIds = rows
        .filter((_, i) => results[i].ok)
        .map((r) => r.id);
    const failedRows = rows
        .map((r, i) => ({ id: r.id, error: results[i].error ?? "unknown" }))
        .filter((_, i) => !results[i].ok);

    if (succeededIds.length > 0) {
        await supabase
            .from("live_activity_pushes")
            .update({ sent: true, sent_at: new Date().toISOString() })
            .in("id", succeededIds);
    }
    for (const fail of failedRows) {
        await supabase
            .from("live_activity_pushes")
            .update({ last_error: fail.error })
            .eq("id", fail.id);
    }

    return new Response(
        JSON.stringify({
            processed: rows.length,
            succeeded: succeededIds.length,
            failed: failedRows.length,
        }),
        { headers: { "Content-Type": "application/json" } }
    );
});
