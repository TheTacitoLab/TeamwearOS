-- Migration 070: Sub-brand tag on leads
-- Lets a lead be assigned to the mother brand (NULL) or a sub-brand, matching
-- jobs/design_tasks/clubs (migration 067). Also unblocks revertJobToLead(),
-- which already writes sub_brand_id into leads.

ALTER TABLE leads ADD COLUMN IF NOT EXISTS sub_brand_id uuid REFERENCES sub_brands(id) ON DELETE SET NULL;
