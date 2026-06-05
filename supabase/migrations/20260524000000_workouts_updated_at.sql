-- Add updated_at to workouts so multi-device sync can detect server-side
-- edits from another device instead of silently overwriting. Future client
-- versions can compare local last-modified vs server updated_at before
-- pushing a stale local copy.

ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Reuse the same trigger function user_preferences already has so on every
-- UPDATE the column tracks the actual mutation time, not just the default.
DROP TRIGGER IF EXISTS workouts_set_updated_at ON workouts;

CREATE TRIGGER workouts_set_updated_at
    BEFORE UPDATE ON workouts
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Backfill: existing rows get updated_at = created_at so the column is
-- meaningful from day one (avoids "all rows updated right now" artifacts
-- that would confuse future conflict-resolution logic).
UPDATE workouts SET updated_at = created_at WHERE updated_at IS NULL OR updated_at = now();
