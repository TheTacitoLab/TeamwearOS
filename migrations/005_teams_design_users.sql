-- =============================================
-- Migration 005: Club Teams, Design Log, Activity, User Permissions
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Club Teams (sports teams within a club)
-- e.g. Westfield FC → U11s Boys, First Team, Ladies
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS club_teams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE NOT NULL,
    team_name TEXT NOT NULL,
    age_group TEXT,
    gender TEXT,
    coach_name TEXT,
    coach_email TEXT,
    coach_phone TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE club_teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_club_teams" ON club_teams
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));
CREATE POLICY "brand_write_club_teams" ON club_teams
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_club_teams_club_id ON club_teams(club_id);
CREATE INDEX IF NOT EXISTS idx_club_teams_brand_id ON club_teams(brand_id);

-- ──────────────────────────────────────────
-- Add club_team_id to jobs (link job to a specific club team)
-- ──────────────────────────────────────────
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS club_team_id UUID REFERENCES club_teams(id) ON DELETE SET NULL;

-- ──────────────────────────────────────────
-- Design Brief Status Log
-- Tracks every status change on a design brief
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_brief_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id UUID REFERENCES design_tasks(id) ON DELETE CASCADE,
    user_id UUID,
    user_name TEXT NOT NULL DEFAULT 'Unknown',
    old_status TEXT,
    new_status TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_brief_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_design_brief_log" ON design_brief_log FOR ALL USING (TRUE);

CREATE INDEX IF NOT EXISTS idx_design_brief_log_task ON design_brief_log(design_task_id);

-- ──────────────────────────────────────────
-- Job Activity Log (replaces simple notes field)
-- Tracks notes, status changes, assignments per job
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS job_activity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id UUID,
    user_name TEXT NOT NULL DEFAULT 'Unknown',
    message TEXT NOT NULL,
    activity_type TEXT DEFAULT 'note'
        CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE job_activity ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_job_activity" ON job_activity
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));
CREATE POLICY "brand_write_job_activity" ON job_activity
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_job_activity_job_id ON job_activity(job_id);

-- ──────────────────────────────────────────
-- User Feature Permissions (per brand, per user)
-- Allows admins to restrict which features a user can see
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_feature_permissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    feature TEXT NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (brand_id, user_id, feature)
);

ALTER TABLE user_feature_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_user_feature_perms" ON user_feature_permissions FOR ALL USING (TRUE);

CREATE INDEX IF NOT EXISTS idx_user_feature_perms ON user_feature_permissions(brand_id, user_id);

-- ──────────────────────────────────────────
-- Add columns to existing tables
-- ──────────────────────────────────────────

-- Club logo (distinct from club_crest_url — downloadable/shareable logo asset)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- Job colour overrides (can override club pantones per job)
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS pantone_main TEXT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS pantone_secondary TEXT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS pantone_accent TEXT;

-- User assignment (who owns this record)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS assigned_user_id UUID;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS assigned_user_id UUID;
ALTER TABLE leads ADD COLUMN IF NOT EXISTS assigned_user_id UUID;

-- ──────────────────────────────────────────
-- updated_at trigger for club_teams
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_club_teams_updated_at ON club_teams;
CREATE TRIGGER update_club_teams_updated_at
    BEFORE UPDATE ON club_teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
