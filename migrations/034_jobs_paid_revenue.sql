-- =============================================
-- Migration 034: Jobs Paid Revenue Tracking
-- Adds paid_at timestamp and revenue_recognized to jobs table.
-- Revenue is recognised when a job enters a kanban stage named "Paid".
-- TeamwearOS
-- =============================================

ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS paid_at           TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revenue_recognized NUMERIC(12,2);

-- Index for fast monthly / YTD revenue queries
CREATE INDEX IF NOT EXISTS idx_jobs_paid_at ON jobs(paid_at) WHERE paid_at IS NOT NULL;
