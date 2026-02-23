-- =============================================
-- Migration 004: Sales / Jobs Module + Enhanced Clubs
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Enhance clubs table with new fields
-- ──────────────────────────────────────────
ALTER TABLE clubs
    ADD COLUMN IF NOT EXISTS club_status TEXT DEFAULT 'retail'
        CHECK (club_status IN ('retail', 'partner', 'partner_plus')),
    ADD COLUMN IF NOT EXISTS address_line1 TEXT,
    ADD COLUMN IF NOT EXISTS address_line2 TEXT,
    ADD COLUMN IF NOT EXISTS address_town TEXT,
    ADD COLUMN IF NOT EXISTS address_county TEXT,
    ADD COLUMN IF NOT EXISTS address_postcode TEXT,
    ADD COLUMN IF NOT EXISTS league TEXT,
    ADD COLUMN IF NOT EXISTS club_crest_url TEXT,
    ADD COLUMN IF NOT EXISTS sponsor_logo_urls JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS pantone_main TEXT,
    ADD COLUMN IF NOT EXISTS pantone_secondary TEXT,
    ADD COLUMN IF NOT EXISTS pantone_accent TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- ──────────────────────────────────────────
-- Jobs table (core sales pipeline record)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    job_name TEXT NOT NULL,
    job_description TEXT,
    job_type TEXT DEFAULT 'new_club'
        CHECK (job_type IN ('new_club', 'repeat_order', 'new_concept', 'new_team')),
    club_type TEXT DEFAULT 'retail'
        CHECK (club_type IN ('retail', 'partner', 'partner_plus')),
    channel TEXT DEFAULT 'direct'
        CHECK (channel IN ('direct', 'store')),
    stage TEXT DEFAULT 'discovery'
        CHECK (stage IN ('discovery', 'concepts', 'awaiting_approval', 'quote', 'paid', 'on_boarding', 'completed')),
    club_id UUID REFERENCES clubs(id) ON DELETE SET NULL,
    range_approved BOOLEAN DEFAULT FALSE,
    completed BOOLEAN DEFAULT FALSE,
    notes TEXT,
    job_number TEXT,                   -- e.g. JOB-0001
    salesperson_id UUID REFERENCES salespeople(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_jobs" ON jobs
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));
CREATE POLICY "brand_write_jobs" ON jobs
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));

CREATE INDEX IF NOT EXISTS jobs_brand_id_idx ON jobs(brand_id);
CREATE INDEX IF NOT EXISTS jobs_stage_idx ON jobs(stage);
CREATE INDEX IF NOT EXISTS jobs_club_id_idx ON jobs(club_id);

-- ──────────────────────────────────────────
-- Job teams (linked team record)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS job_teams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    manager_name TEXT,
    manager_email TEXT,
    manager_phone TEXT,
    sponsor_logo_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE job_teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_job_teams" ON job_teams
    USING (job_id IN (
        SELECT id FROM jobs WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));
CREATE POLICY "brand_write_job_teams" ON job_teams
    FOR ALL USING (job_id IN (
        SELECT id FROM jobs WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));

-- ──────────────────────────────────────────
-- Design tasks (one per job)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE UNIQUE,
    design_summary TEXT,
    design_appetite TEXT,             -- 'minimal', 'moderate', 'bold', 'bespoke'
    status TEXT DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'revisions', 'in_review', 'awaiting_approval', 'complete')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_design_tasks" ON design_tasks
    USING (job_id IN (
        SELECT id FROM jobs WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));
CREATE POLICY "brand_write_design_tasks" ON design_tasks
    FOR ALL USING (job_id IN (
        SELECT id FROM jobs WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));

-- ──────────────────────────────────────────
-- Design versions (V1, V2 ... per design task)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_versions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id UUID REFERENCES design_tasks(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL DEFAULT 1,
    version_label TEXT,               -- 'V1', 'V2', etc.
    file_url TEXT,
    thumbnail_url TEXT,
    notes TEXT,
    status TEXT DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_design_versions" ON design_versions
    USING (design_task_id IN (
        SELECT id FROM design_tasks WHERE job_id IN (
            SELECT id FROM jobs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
            )
        )
    ));
CREATE POLICY "brand_write_design_versions" ON design_versions
    FOR ALL USING (design_task_id IN (
        SELECT id FROM design_tasks WHERE job_id IN (
            SELECT id FROM jobs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
            )
        )
    ));

CREATE INDEX IF NOT EXISTS design_versions_task_id_idx ON design_versions(design_task_id);

-- Auto updated_at triggers
CREATE TRIGGER update_jobs_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_design_tasks_updated_at
    BEFORE UPDATE ON design_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Job number sequence function
CREATE OR REPLACE FUNCTION get_next_job_number(p_brand_id UUID)
RETURNS TEXT AS $$
DECLARE
    job_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO job_count FROM jobs WHERE brand_id = p_brand_id;
    RETURN 'JOB-' || LPAD((job_count + 1)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;
