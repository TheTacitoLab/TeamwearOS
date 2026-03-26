-- =====================================================================
-- 025: Sales Consolidation
-- Merges Prospecting into Sales with new unified pipeline:
--   LEADS (kanban) → JOBS (kanban) → PRODUCTION → COMPLETED
-- =====================================================================

-- 1. Add Shopify Draft Order URL field to jobs
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS shopify_draft_order_url TEXT;

-- 2. Migrate job stages to new names
--    Old: discovery, concepts, awaiting_approval, quote, paid, on_boarding, completed
--    New: discovery, concepts, final_mockups, order_details, quoted, completed
UPDATE jobs SET stage = 'final_mockups'  WHERE stage = 'awaiting_approval';
UPDATE jobs SET stage = 'order_details'  WHERE stage = 'quote';
UPDATE jobs SET stage = 'quoted'         WHERE stage = 'paid';
UPDATE jobs SET stage = 'completed'      WHERE stage = 'on_boarding';

-- 3. Remove the 3-stage limit check is enforced in the UI only — no DB constraint to change.
--    New defaults (Not Contacted, Attempted Contact, In Discussion) will be seeded by JS
--    when a brand has no kanban_stages.

-- 4. Grant RLS access for new column (inherits existing jobs policy)
-- No separate policy needed — existing jobs RLS covers all columns.
