-- =====================================================================
-- 025: Sales Consolidation
-- Merges Prospecting into Sales with new unified pipeline:
--   LEADS (kanban) → JOBS (kanban) → PRODUCTION → COMPLETED
-- =====================================================================

-- 1. Add Shopify Draft Order URL field to jobs
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS shopify_draft_order_url TEXT;

-- 2. Drop the existing stage check constraint so we can rename stage values
ALTER TABLE jobs DROP CONSTRAINT IF EXISTS jobs_stage_check;

-- 3. Migrate job stages to new names
--    Old: discovery, concepts, awaiting_approval, quote, paid, on_boarding, completed
--    New: discovery, concepts, final_mockups, order_details, quoted, completed
UPDATE jobs SET stage = 'final_mockups'  WHERE stage = 'awaiting_approval';
UPDATE jobs SET stage = 'order_details'  WHERE stage = 'quote';
UPDATE jobs SET stage = 'quoted'         WHERE stage = 'paid';
UPDATE jobs SET stage = 'completed'      WHERE stage = 'on_boarding';

-- 4. Re-add the check constraint with the new stage values
ALTER TABLE jobs ADD CONSTRAINT jobs_stage_check
    CHECK (stage IN ('discovery','concepts','final_mockups','order_details','quoted','completed'));

-- 5. Grant RLS access for new column (inherits existing jobs policy)
-- No separate policy needed — existing jobs RLS covers all columns.
