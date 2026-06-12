-- ====================================================================
-- Tear down the Live Activity push infrastructure
-- ====================================================================
-- The Live Activity remote-push pipeline was removed from the iOS app
-- in 1.0 — phase transitions only happen via local `Activity.update`
-- now, and even the local Live Activity itself was removed. None of
-- the Supabase plumbing is reachable any more, so drop it to free the
-- pg_cron slot and reduce the attack surface from the (publicly
-- callable, verify_jwt = false) Edge Functions.
--
-- Edge Functions themselves must also be removed via the Supabase
-- dashboard or CLI:
--   supabase functions delete schedule-live-activity
--   supabase functions delete cancel-live-activity
--   supabase functions delete send-due-live-activity-pushes
-- ====================================================================

-- Stop pg_cron from invoking the (about-to-be-dropped) dispatcher.
-- Wrapped in dynamic SQL guarded by a pg_extension check: bare
-- cron.unschedule calls fail at parse time on a fresh database where
-- pg_cron isn't installed (db reset / preview branches), even with a
-- WHERE EXISTS guard.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'live-activity-push-dispatcher') THEN
            PERFORM cron.unschedule('live-activity-push-dispatcher');
        END IF;
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'live-activity-push-prune') THEN
            PERFORM cron.unschedule('live-activity-push-prune');
        END IF;
    END IF;
END
$$;

-- Drop the SQL helpers.
DROP FUNCTION IF EXISTS public.dispatch_due_live_activity_pushes();
DROP FUNCTION IF EXISTS public.claim_due_live_activity_pushes(INT);
DROP FUNCTION IF EXISTS public.prune_old_live_activity_pushes();

-- Drop the queue table itself.
DROP TABLE IF EXISTS public.live_activity_pushes;
