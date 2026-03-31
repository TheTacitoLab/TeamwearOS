-- =====================================================================
-- 027: Sales Job Enhancements
-- Adds: estimated_revenue, next_action, next_action_due_date,
--       next_action_history to the jobs table.
-- These power the Sales Home kanban revenue totals, preview panel
-- next-action editor, and completed-action history.
-- =====================================================================

-- 1. Estimated revenue value (£)
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS estimated_revenue NUMERIC(12,2);

-- 2. Current next action (free text)
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS next_action TEXT;

-- 3. Due date for the current next action
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS next_action_due_date DATE;

-- 4. History of completed actions (JSONB array)
--    Each element: { action, due_date, completed_at }
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS next_action_history JSONB NOT NULL DEFAULT '[]';

-- 5. Index to quickly find jobs with overdue actions
CREATE INDEX IF NOT EXISTS idx_jobs_next_action_due
    ON jobs (brand_id, next_action_due_date)
    WHERE next_action_due_date IS NOT NULL;
