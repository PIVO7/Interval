-- ====================================================================
-- Update dispatcher: hardcoded edge function URL, no auth header
-- ====================================================================
-- The previous migration tried to read `app.edge_function_url` and
-- `app.service_role_key` via `current_setting`, which would have been
-- set with `ALTER DATABASE postgres SET ...`. Turns out Supabase
-- restricts that for the standard postgres role.
--
-- Two changes in this update:
--
-- 1. URL is hardcoded into the SQL function. Project ref doesn't
--    change so this is fine.
-- 2. No Authorization header — the target Edge Function is configured
--    with verify_jwt = false in supabase/config.toml, so the call from
--    pg_net needs no JWT. The function only processes already-due rows
--    (idempotent) and takes no parameters, so being publicly callable
--    doesn't widen the attack surface.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.dispatch_due_live_activity_pushes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    edge_url   CONSTANT TEXT := 'https://gfescsrjilmprsyuzipj.supabase.co/functions/v1/send-due-live-activity-pushes';
    iterations INT := 0;
BEGIN
    WHILE iterations < 55 LOOP
        IF EXISTS (
            SELECT 1
            FROM public.live_activity_pushes
            WHERE NOT sent AND scheduled_at <= NOW()
            LIMIT 1
        ) THEN
            PERFORM net.http_post(
                url := edge_url,
                headers := jsonb_build_object('Content-Type', 'application/json'),
                body := '{}'::jsonb
            );
        END IF;
        PERFORM pg_sleep(1);
        iterations := iterations + 1;
    END LOOP;
END;
$$;
