-- =============================================
-- Migration 018: Link Order Forms to Jobs
-- TeamwearOS
-- =============================================
-- Adds an optional job_id FK to order_forms so that when a form
-- is created from a Sales Job Record it is tied to that specific job.
--
-- Behaviour:
--   • Forms created from a job:  job_id IS NOT NULL → public form shows
--     only the products selected on that job (job_products table).
--   • Forms created from a club: job_id IS NULL     → public form shows
--     all active club products (backward-compatible).
-- =============================================

ALTER TABLE order_forms
    ADD COLUMN IF NOT EXISTS job_id UUID REFERENCES jobs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_order_forms_job_id ON order_forms(job_id);
