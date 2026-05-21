-- ====================================================================
-- Live Activity push queue + dispatcher
-- ====================================================================
-- Supports remote-driven Live Activity updates for the workout timer:
-- the app schedules ALL phase boundaries upfront when a workout starts,
-- rows are inserted here, and pg_cron periodically asks the Edge Function
-- to deliver due rows to APNs. End result: phase transitions reach the
-- Live Activity even when the iPhone is locked + no audio is playing.
-- ====================================================================

-- ----- Extensions ---------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ----- Queue table --------------------------------------------------

CREATE TABLE IF NOT EXISTS public.live_activity_pushes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token           TEXT NOT NULL,
    bundle_id       TEXT NOT NULL,
    scheduled_at    TIMESTAMPTZ NOT NULL,
    event           TEXT NOT NULL CHECK (event IN ('update', 'end')),
    payload         JSONB NOT NULL,
    sent            BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at         TIMESTAMPTZ,
    attempt_count   INT NOT NULL DEFAULT 0,
    last_error      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hot path: "find unsent pushes that are due".
CREATE INDEX IF NOT EXISTS live_activity_pushes_due_idx
    ON public.live_activity_pushes (scheduled_at)
    WHERE NOT sent;

-- Cancel/replace by token.
CREATE INDEX IF NOT EXISTS live_activity_pushes_token_idx
    ON public.live_activity_pushes (token)
    WHERE NOT sent;

-- RLS on with no policies → only the service role (Edge Functions) can
-- touch this table. End users never access it directly.
ALTER TABLE public.live_activity_pushes ENABLE ROW LEVEL SECURITY;

-- ----- Atomic claim function ---------------------------------------
-- Returns up to `batch_size` due rows AND marks them as having one more
-- attempt — all in a single statement so concurrent Edge-Function runs
-- don't pick up the same row twice. Uses SKIP LOCKED.

CREATE OR REPLACE FUNCTION public.claim_due_live_activity_pushes(batch_size INT DEFAULT 50)
RETURNS SETOF public.live_activity_pushes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH due AS (
        SELECT id
        FROM public.live_activity_pushes
        WHERE NOT sent AND scheduled_at <= NOW()
        ORDER BY scheduled_at
        LIMIT batch_size
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.live_activity_pushes p
    SET attempt_count = p.attempt_count + 1
    FROM due
    WHERE p.id = due.id
    RETURNING p.*;
END;
$$;

-- ----- Dispatcher loop (initial version) ---------------------------
-- This version uses database-level settings via `current_setting` —
-- which turned out to be blocked in Supabase for the standard postgres
-- role. The next migration (20260521130000_dispatcher_hardcoded_url)
-- replaces this with a hardcoded-URL version. Kept here for history.

CREATE OR REPLACE FUNCTION public.dispatch_due_live_activity_pushes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    edge_url   TEXT;
    edge_key   TEXT;
    iterations INT := 0;
BEGIN
    edge_url := current_setting('app.edge_function_url', true);
    edge_key := current_setting('app.service_role_key', true);

    IF edge_url IS NULL OR edge_key IS NULL THEN
        RAISE WARNING 'app.edge_function_url or app.service_role_key not set';
        RETURN;
    END IF;

    WHILE iterations < 55 LOOP
        IF EXISTS (
            SELECT 1
            FROM public.live_activity_pushes
            WHERE NOT sent AND scheduled_at <= NOW()
            LIMIT 1
        ) THEN
            PERFORM net.http_post(
                url := edge_url || '/functions/v1/send-due-live-activity-pushes',
                headers := jsonb_build_object(
                    'Authorization', 'Bearer ' || edge_key,
                    'Content-Type', 'application/json'
                ),
                body := '{}'::jsonb
            );
        END IF;
        PERFORM pg_sleep(1);
        iterations := iterations + 1;
    END LOOP;
END;
$$;

-- ----- Schedule the dispatcher --------------------------------------

SELECT cron.schedule(
    'live-activity-push-dispatcher',
    '* * * * *',  -- every minute; inner loop covers the 55 seconds
    $$SELECT public.dispatch_due_live_activity_pushes()$$
);

-- ----- Cleanup (optional) -------------------------------------------
-- Daily job: prune rows older than 7 days regardless of status.

CREATE OR REPLACE FUNCTION public.prune_old_live_activity_pushes()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM public.live_activity_pushes
    WHERE created_at < NOW() - INTERVAL '7 days';
$$;

SELECT cron.schedule(
    'live-activity-push-prune',
    '0 4 * * *',  -- 04:00 daily
    $$SELECT public.prune_old_live_activity_pushes()$$
);
