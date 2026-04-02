-- Migration 030: Add next_step fields to jobs table for GTM dashboard
-- Run once against your Supabase database

ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS next_step        TEXT,
    ADD COLUMN IF NOT EXISTS next_step_deadline DATE;

COMMENT ON COLUMN jobs.next_step         IS 'The immediate next action required for this job';
COMMENT ON COLUMN jobs.next_step_deadline IS 'Date by which the next step should be completed';
