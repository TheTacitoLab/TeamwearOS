-- Migration 031: Add multi-owner support to design_tasks
-- Leads, Clubs, and Jobs already have assigned_user_ids[].
-- Design Tasks only had a single owner_id — add owner_ids UUID[] array for parity.

ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS owner_ids UUID[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_design_tasks_owner_ids
    ON design_tasks USING GIN(owner_ids);
