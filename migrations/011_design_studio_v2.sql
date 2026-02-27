-- =============================================
-- Migration 011: Design Studio V2
-- Enhanced Design Task Records — standalone tasks
-- with full lifecycle: Overview, Assets, Versions, Delivery
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Extend design_tasks table
-- ──────────────────────────────────────────

-- Add brand_id so tasks can exist without a job
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES brands(id) ON DELETE CASCADE;

-- Make job_id optional (tasks can be created standalone or from a job)
ALTER TABLE design_tasks
    ALTER COLUMN job_id DROP NOT NULL;

-- Core identity fields
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS task_name TEXT,
    ADD COLUMN IF NOT EXISTS task_ref  TEXT,
    ADD COLUMN IF NOT EXISTS club_id   UUID REFERENCES clubs(id) ON DELETE SET NULL;

-- Scheduling
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS due_date DATE;

-- Classification
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS job_type TEXT
        CHECK (job_type IN (
            'new_club_full_range', 'sales_order_new_design',
            'team_sponsor_change', 'one_off',
            'special_edition', 'internal_task'
        )),
    ADD COLUMN IF NOT EXISTS design_types TEXT[] DEFAULT '{}';

-- Design content
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS design_brief TEXT;

-- Products linked (array of club_product IDs)
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS products_required UUID[] DEFAULT '{}';

-- Assignment
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS assigned_designer_id   UUID,
    ADD COLUMN IF NOT EXISTS assigned_designer_name TEXT;

-- Lifecycle timestamps
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS delivered_at  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completed_at  TIMESTAMPTZ;

-- Drop and recreate status constraint to include new statuses
ALTER TABLE design_tasks
    DROP CONSTRAINT IF EXISTS design_tasks_status_check;

ALTER TABLE design_tasks
    ADD CONSTRAINT design_tasks_status_check
    CHECK (status IN (
        'new', 'in_progress', 'revisions',
        'in_review', 'awaiting_approval',
        'delivered', 'completed'
    ));

-- Backfill brand_id from linked job
UPDATE design_tasks dt
SET brand_id = j.brand_id
FROM jobs j
WHERE dt.job_id = j.id AND dt.brand_id IS NULL;

-- ──────────────────────────────────────────
-- Extend brands table
-- ──────────────────────────────────────────

ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS design_ref_prefix    TEXT    DEFAULT 'DES',
    ADD COLUMN IF NOT EXISTS design_task_counter  INTEGER DEFAULT 0;

-- ──────────────────────────────────────────
-- Design Task Assets (reference files & client briefs)
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS design_task_assets (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id UUID REFERENCES design_tasks(id) ON DELETE CASCADE NOT NULL,
    brand_id       UUID REFERENCES brands(id) ON DELETE CASCADE,
    file_name      TEXT NOT NULL,
    file_url       TEXT NOT NULL,
    file_type      TEXT,
    file_size      BIGINT,
    notes          TEXT,
    uploaded_by    UUID,
    uploaded_by_name TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_task_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_access_design_task_assets" ON design_task_assets
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_design_task_assets" ON design_task_assets
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_design_task_assets_task ON design_task_assets(design_task_id);
CREATE INDEX IF NOT EXISTS idx_design_task_assets_brand ON design_task_assets(brand_id);

-- ──────────────────────────────────────────
-- Design Task Delivery (final approved artwork files)
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS design_task_delivery (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id UUID REFERENCES design_tasks(id) ON DELETE CASCADE NOT NULL,
    brand_id       UUID REFERENCES brands(id) ON DELETE CASCADE,
    file_name      TEXT NOT NULL,
    file_url       TEXT NOT NULL,
    file_type      TEXT,
    file_size      BIGINT,
    notes          TEXT,
    uploaded_by    UUID,
    uploaded_by_name TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_task_delivery ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_access_design_task_delivery" ON design_task_delivery
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_design_task_delivery" ON design_task_delivery
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_design_task_delivery_task ON design_task_delivery(design_task_id);
CREATE INDEX IF NOT EXISTS idx_design_task_delivery_brand ON design_task_delivery(brand_id);

-- ──────────────────────────────────────────
-- RPC: increment design task counter (atomic)
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION increment_design_task_counter(brand_id_input UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_counter INTEGER;
BEGIN
    UPDATE brands
    SET design_task_counter = COALESCE(design_task_counter, 0) + 1
    WHERE id = brand_id_input
    RETURNING design_task_counter INTO new_counter;
    RETURN new_counter;
END;
$$;

-- ──────────────────────────────────────────
-- Performance indexes
-- ──────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_design_tasks_brand  ON design_tasks(brand_id);
CREATE INDEX IF NOT EXISTS idx_design_tasks_club   ON design_tasks(club_id);
CREATE INDEX IF NOT EXISTS idx_design_tasks_due    ON design_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_design_tasks_status ON design_tasks(status);
