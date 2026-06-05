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
SELECT cron.unschedule('live-activity-push-dispatcher')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'live-activity-push-dispatcher');

SELECT cron.unschedule('live-activity-push-prune')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'live-activity-push-prune');

-- Drop the SQL helpers.
DROP FUNCTION IF EXISTS public.dispatch_due_live_activity_pushes();
DROP FUNCTION IF EXISTS public.claim_due_live_activity_pushes(INT);
DROP FUNCTION IF EXISTS public.prune_old_live_activity_pushes();

-- Drop the queue table itself.
DROP TABLE IF EXISTS public.live_activity_pushes;
