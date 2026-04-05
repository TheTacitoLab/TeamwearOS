-- =============================================
-- Migration 033: Job Kanban Stages
-- Configurable pipeline stages for the Jobs kanban board,
-- mirroring the existing kanban_stages system for Leads.
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Job Kanban Stages table
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS job_kanban_stages (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id   UUID REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    name       TEXT NOT NULL,
    color      TEXT DEFAULT '#64748b',
    position   INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE job_kanban_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_job_kanban_stages" ON job_kanban_stages
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_job_kanban_stages" ON job_kanban_stages
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_job_kanban_stages_brand ON job_kanban_stages(brand_id);

-- ──────────────────────────────────────────
-- Link jobs to their configurable stage
-- ──────────────────────────────────────────

ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS job_kanban_stage_id UUID REFERENCES job_kanban_stages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_job_kanban_stage ON jobs(job_kanban_stage_id);
