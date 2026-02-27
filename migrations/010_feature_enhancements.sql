-- =============================================
-- Migration 010: Feature Enhancements
-- Tasks, Activity Feed, Multi-User Assignment,
-- Lead-to-Job Conversion, Enhanced Pipeline
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Extend job_activity: add task support
-- ──────────────────────────────────────────

-- Drop and recreate the check constraint to include 'task'
ALTER TABLE job_activity
    DROP CONSTRAINT IF EXISTS job_activity_activity_type_check;

ALTER TABLE job_activity
    ADD CONSTRAINT job_activity_activity_type_check
    CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task'));

-- Add task_completed field
ALTER TABLE job_activity
    ADD COLUMN IF NOT EXISTS task_completed BOOLEAN DEFAULT FALSE;

-- Add dismissed_by: array of user IDs who dismissed this notification in their feed
ALTER TABLE job_activity
    ADD COLUMN IF NOT EXISTS dismissed_by UUID[] DEFAULT '{}';

-- ──────────────────────────────────────────
-- Club Activity Log (if not already created)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS club_activity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id UUID,
    user_name TEXT NOT NULL DEFAULT 'Unknown',
    message TEXT NOT NULL,
    activity_type TEXT DEFAULT 'note'
        CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task')),
    task_completed BOOLEAN DEFAULT FALSE,
    dismissed_by UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE club_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_access_club_activity" ON club_activity
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_club_activity" ON club_activity
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_club_activity_club_id ON club_activity(club_id);
CREATE INDEX IF NOT EXISTS idx_club_activity_brand_id ON club_activity(brand_id);

-- ──────────────────────────────────────────
-- Lead Activity Log (notes/tasks on leads)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_activity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id UUID,
    user_name TEXT NOT NULL DEFAULT 'Unknown',
    message TEXT NOT NULL,
    activity_type TEXT DEFAULT 'note'
        CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task')),
    task_completed BOOLEAN DEFAULT FALSE,
    dismissed_by UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lead_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "brand_access_lead_activity" ON lead_activity
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY "brand_write_lead_activity" ON lead_activity
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_lead_activity_lead_id ON lead_activity(lead_id);

-- ──────────────────────────────────────────
-- Lead: Add conversion tracking
-- ──────────────────────────────────────────
ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS converted_to_job_id UUID REFERENCES jobs(id) ON DELETE SET NULL;

-- Drop and recreate status constraint to include 'converted'
ALTER TABLE leads
    DROP CONSTRAINT IF EXISTS leads_status_check;

ALTER TABLE leads
    ADD CONSTRAINT leads_status_check
    CHECK (status IN ('not_contacted', 'in_discussion', 'archived', 'converted'));

-- ──────────────────────────────────────────
-- Multi-user assignment: assigned_user_ids arrays
-- These store all assigned user IDs for collaboration
-- (assigned_user_id remains for backward compatibility)
-- ──────────────────────────────────────────
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

ALTER TABLE clubs
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

-- Backfill: copy existing assigned_user_id into assigned_user_ids array
UPDATE jobs
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

UPDATE clubs
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

UPDATE leads
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

-- ──────────────────────────────────────────
-- Indexes for efficient querying
-- ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_user_ids ON jobs USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_clubs_assigned_user_ids ON clubs USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_user_ids ON leads USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_job_activity_dismissed_by ON job_activity USING GIN (dismissed_by);
