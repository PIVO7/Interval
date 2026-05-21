# Supabase — Live Activity push backend

Pre-schedules every phase boundary of a workout as a queued APNs push,
so iOS Live Activity transitions arrive on locked devices without the
app needing background runtime.

## Architecture (recap)

```
iOS app                  Supabase Edge Functions          APNs
   │                              │                        │
   │ start workout                │                        │
   ├─► schedule-live-activity ───►│ INSERT rows            │
   │   (token + full schedule)    │ into queue table       │
   │                              │                        │
   │                              │ pg_cron fires          │
   │                              │ dispatcher every       │
   │                              │ second (looped inside  │
   │                              │ a per-minute job)      │
   │                              │      │                 │
   │                              │      ▼                 │
   │                              │ send-due-* picks       │
   │                              │ ready rows, signs JWT, │
   │                              │ POSTs to APNs ────────►│
   │                              │                        │
   │                              │             APNs ──────► Live Activity
   │ user stops                   │             delivers     update appears
   ├─► cancel-live-activity ─────►│ DELETE remaining        on locked device
       (token)                    │ rows for token          (no app needed)
```

## One-time setup

### 1. Install + link

```bash
# Inside the project root (where this folder lives)
brew install supabase/tap/supabase   # if not already installed
supabase login                        # browser flow
supabase link --project-ref gfescsrjilmprsyuzipj
```

### 2. Push the migration

```bash
supabase db push
```

This creates the `live_activity_pushes` table, the
`claim_due_live_activity_pushes` and `dispatch_due_live_activity_pushes`
functions, and the two pg_cron jobs (dispatcher every minute, prune
daily).

If your project doesn't have `pg_cron` / `pg_net` enabled yet, enable
both in the dashboard: **Database → Extensions** → flip them on. Then
re-run `supabase db push`.

### 3. Set the APNs secrets for the dispatcher Edge Function

These ship to the Edge Functions runtime, NOT to the database:

```bash
# Apple Team ID — visible top-right on developer.apple.com
supabase secrets set APNS_TEAM_ID=VB6FS3N78T

# APNs Auth Key ID — the 10-char string from the key you created
supabase secrets set APNS_KEY_ID=76C427WRHC

# The .p8 file contents (multi-line PEM). Use a heredoc:
supabase secrets set APNS_AUTH_KEY="$(cat ~/Downloads/AuthKey_76C427WRHC.p8)"
```

Verify:
```bash
supabase secrets list
```

Should show three rows. Their values are masked but their presence
proves the secrets were set.

### 5. Deploy the three Edge Functions

```bash
supabase functions deploy schedule-live-activity
supabase functions deploy cancel-live-activity
supabase functions deploy send-due-live-activity-pushes
```

That's it for setup. From now on, every `supabase db push` /
`supabase functions deploy` from this folder updates the live project.

## Sandbox vs. production APNs

`api.push.apple.com` is the **production** APNs host. Xcode debug
builds installed via cable carry the `aps-environment = development`
entitlement and need pushes from `api.sandbox.push.apple.com`.

TestFlight + App Store distribution swap the entitlement to
`production`, so the default host works.

If you want to test from an Xcode debug build, set an extra secret:
```bash
supabase secrets set APNS_HOST=api.sandbox.push.apple.com
```

…and remember to flip it back before re-deploying for TestFlight builds.

## Observability

In the Supabase dashboard:

- **Database → Tables → live_activity_pushes** — see queued/sent rows.
  `last_error` tells you why a push failed (e.g. `BadDeviceToken`).
- **Edge Functions → Logs** — see Deno `console.log` output from each
  function invocation, including APNs response bodies on failure.
- **Database → Cron jobs** — verify the dispatcher and prune jobs are
  scheduled and last-run times look healthy.

## Quotas to watch

- **APNs** has no daily limit for Live Activity updates from one app.
  100% throughput is normal.
- **Supabase Edge Functions** — free tier: 500K invocations/month;
  Pro: 2M/month. Our dispatcher fires the Edge Function only when
  pushes are due, so idle minutes cost nothing. Heavy usage estimate:
  17 pushes per 8-round workout × 5 workouts/day × 30 days =
  ~2,550 invocations/month per active daily user.
- **pg_cron** — no quota; runs as a built-in PostgreSQL worker.

## Local testing

Edge Functions can be served locally:
```bash
supabase functions serve
```
Then point the app at `http://localhost:54321` instead of the cloud
URL by overriding `SupabaseConfig.url`. Useful for iterating on the
schedule logic without touching production.
