-- Migration 050: Next Action columns on design_tasks and clubs
-- Note: clubs.assigned_user_ids already exists (migration 010), and the
-- saveMultiUserAssignment('club', ids) save path is already wired; we just
-- need to surface the Owner dropdown in the club edit modal (done in UI).

CREATE INDEX IF NOT EXISTS idx_clubs_assigned_user_ids ON clubs USING GIN (assigned_user_ids);

-- Next Action columns on design_tasks (jobs already has these from migration 027)
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS next_action           TEXT;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS next_action_due_date  DATE;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS next_action_history   JSONB DEFAULT '[]'::jsonb;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS next_action_created_by UUID;

-- Next Action columns on clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS next_action           TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS next_action_due_date  DATE;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS next_action_history   JSONB DEFAULT '[]'::jsonb;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS next_action_created_by UUID;

-- Add next_action_created_by to jobs (existing columns from migration 027 didn't include it)
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS next_action_created_by UUID;
