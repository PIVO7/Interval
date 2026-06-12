-- Repair the updated_at backfill from 20260524000000_workouts_updated_at.
--
-- That migration created the BEFORE UPDATE trigger *before* running its
-- backfill UPDATE, so set_updated_at() overwrote the intended
-- `SET updated_at = created_at` with now() — stamping every pre-existing
-- row with the migration timestamp. Any future conflict-resolution logic
-- comparing timestamps would see those rows as "recently changed".
--
-- Re-run the backfill with the trigger disabled. The app has not launched
-- yet, so the table holds only test data — resetting updated_at to
-- created_at across the board is correct and loses nothing.

ALTER TABLE public.workouts DISABLE TRIGGER workouts_set_updated_at;
UPDATE public.workouts SET updated_at = created_at;
ALTER TABLE public.workouts ENABLE TRIGGER workouts_set_updated_at;
