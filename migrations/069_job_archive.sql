-- Migration 069: Support reverting a sales job back to a lead
-- Reverting creates a new lead from the job's top-level details and ARCHIVES
-- the job (rather than deleting it) so linked design tasks, kit orders and
-- products are preserved. Archived jobs are hidden from the active pipeline.

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS archived         boolean NOT NULL DEFAULT false;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS reverted_lead_id uuid REFERENCES leads(id) ON DELETE SET NULL;
