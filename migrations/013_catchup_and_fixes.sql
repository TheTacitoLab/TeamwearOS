-- =============================================
-- Migration 013: Catch-Up & Fixes
-- Idempotent. Applies everything from 010 + 011
-- that may have been missed, plus critical bug fixes:
--
--   FIX 1 — Status 'complete' → 'completed' backfill
--            (prevents ADD CONSTRAINT failure in 011)
--   FIX 2 — design_tasks RLS rewritten to use brand_id directly
--            (standalone tasks with job_id IS NULL were invisible)
--   FIX 3 — design_versions RLS updated to match
--   FIX 4 — design_feed gets design_task_id for standalone tasks
--   FIX 5 — Enable RLS on design_annotations and design_feed
--            (both flagged CRITICAL by Supabase security linter)
--   FIX 6 — Add SET search_path to all SECURITY DEFINER functions
--            (mutable search path flagged by Supabase security linter)
--
-- Safe to run even if 010 / 011 were partially applied.
-- TeamwearOS
-- =============================================


-- ══════════════════════════════════════════════════════════════
-- SECTION 1: FROM 010 — Activity Feeds & Multi-User Assignment
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- Extend job_activity: add 'task' type + new columns
-- ──────────────────────────────────────────
ALTER TABLE job_activity
    DROP CONSTRAINT IF EXISTS job_activity_activity_type_check;

ALTER TABLE job_activity
    ADD CONSTRAINT job_activity_activity_type_check
    CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task'));

ALTER TABLE job_activity
    ADD COLUMN IF NOT EXISTS task_completed BOOLEAN DEFAULT FALSE;

ALTER TABLE job_activity
    ADD COLUMN IF NOT EXISTS dismissed_by UUID[] DEFAULT '{}';

-- ──────────────────────────────────────────
-- Club Activity Log
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS club_activity (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    club_id        UUID REFERENCES clubs(id) ON DELETE CASCADE,
    brand_id       UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id        UUID,
    user_name      TEXT NOT NULL DEFAULT 'Unknown',
    message        TEXT NOT NULL,
    activity_type  TEXT DEFAULT 'note'
        CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task')),
    task_completed BOOLEAN DEFAULT FALSE,
    dismissed_by   UUID[] DEFAULT '{}',
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE club_activity ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'club_activity' AND policyname = 'brand_access_club_activity'
    ) THEN
        CREATE POLICY "brand_access_club_activity" ON club_activity
            USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'club_activity' AND policyname = 'brand_write_club_activity'
    ) THEN
        CREATE POLICY "brand_write_club_activity" ON club_activity
            FOR ALL USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_club_activity_club_id  ON club_activity(club_id);
CREATE INDEX IF NOT EXISTS idx_club_activity_brand_id ON club_activity(brand_id);

-- ──────────────────────────────────────────
-- Lead Activity Log
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_activity (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lead_id        UUID REFERENCES leads(id) ON DELETE CASCADE,
    brand_id       UUID REFERENCES brands(id) ON DELETE CASCADE,
    user_id        UUID,
    user_name      TEXT NOT NULL DEFAULT 'Unknown',
    message        TEXT NOT NULL,
    activity_type  TEXT DEFAULT 'note'
        CHECK (activity_type IN ('note', 'status_change', 'assignment', 'system', 'task')),
    task_completed BOOLEAN DEFAULT FALSE,
    dismissed_by   UUID[] DEFAULT '{}',
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lead_activity ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'lead_activity' AND policyname = 'brand_access_lead_activity'
    ) THEN
        CREATE POLICY "brand_access_lead_activity" ON lead_activity
            USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'lead_activity' AND policyname = 'brand_write_lead_activity'
    ) THEN
        CREATE POLICY "brand_write_lead_activity" ON lead_activity
            FOR ALL USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_lead_activity_lead_id  ON lead_activity(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_activity_brand_id ON lead_activity(brand_id);

-- ──────────────────────────────────────────
-- Leads: conversion tracking + 'converted' status
-- ──────────────────────────────────────────
ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS converted_to_job_id UUID REFERENCES jobs(id) ON DELETE SET NULL;

ALTER TABLE leads
    DROP CONSTRAINT IF EXISTS leads_status_check;

ALTER TABLE leads
    ADD CONSTRAINT leads_status_check
    CHECK (status IN ('not_contacted', 'in_discussion', 'archived', 'converted'));

-- ──────────────────────────────────────────
-- Multi-user assignment: assigned_user_ids arrays
-- ──────────────────────────────────────────
ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

ALTER TABLE clubs
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

ALTER TABLE leads
    ADD COLUMN IF NOT EXISTS assigned_user_ids UUID[] DEFAULT '{}';

-- Backfill singular → array (only where array is still empty)
UPDATE jobs
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL
      AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

UPDATE clubs
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL
      AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

UPDATE leads
    SET assigned_user_ids = ARRAY[assigned_user_id]
    WHERE assigned_user_id IS NOT NULL
      AND (assigned_user_ids IS NULL OR array_length(assigned_user_ids, 1) IS NULL);

-- GIN indexes for array lookups
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_user_ids        ON jobs        USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_clubs_assigned_user_ids       ON clubs       USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_user_ids       ON leads       USING GIN (assigned_user_ids);
CREATE INDEX IF NOT EXISTS idx_job_activity_dismissed_by     ON job_activity USING GIN (dismissed_by);


-- ══════════════════════════════════════════════════════════════
-- SECTION 2: FROM 011 — Design Studio V2 (with bug fixes)
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- Extend design_tasks: standalone support
-- ──────────────────────────────────────────

-- brand_id allows tasks to exist without a job
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES brands(id) ON DELETE CASCADE;

-- Make job_id optional (already nullable if column allows NULL)
ALTER TABLE design_tasks
    ALTER COLUMN job_id DROP NOT NULL;

-- Core identity
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS task_name TEXT;
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS task_ref TEXT;
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id) ON DELETE SET NULL;

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
        ));
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS design_types TEXT[] DEFAULT '{}';

-- Design content
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS design_brief TEXT;

-- Products linked
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS products_required UUID[] DEFAULT '{}';

-- Assignment
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS assigned_designer_id   UUID;
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS assigned_designer_name TEXT;

-- Lifecycle timestamps
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- ──────────────────────────────────────────
-- FIX 1: Drop constraint FIRST, then backfill, then re-add.
-- The old constraint (from 004) only allows 'complete', so updating
-- to 'completed' while the constraint is still active causes a
-- check violation. Order must be: DROP → UPDATE → ADD CONSTRAINT.
-- ──────────────────────────────────────────

-- Step 1: Drop old constraint so the UPDATE below is not blocked
ALTER TABLE design_tasks
    DROP CONSTRAINT IF EXISTS design_tasks_status_check;

-- Step 2: Migrate old 'complete' rows to 'completed'
UPDATE design_tasks
    SET status = 'completed'
    WHERE status = 'complete';

-- Step 3: Add updated constraint with 'delivered' + 'completed'
ALTER TABLE design_tasks
    ADD CONSTRAINT design_tasks_status_check
    CHECK (status IN (
        'new', 'in_progress', 'revisions',
        'in_review', 'awaiting_approval',
        'delivered', 'completed'
    ));

-- Backfill brand_id from linked job for existing records
UPDATE design_tasks dt
SET brand_id = j.brand_id
FROM jobs j
WHERE dt.job_id = j.id AND dt.brand_id IS NULL;

-- ──────────────────────────────────────────
-- Extend brands: design task counter + ref prefix
-- ──────────────────────────────────────────
ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS design_ref_prefix   TEXT    DEFAULT 'DES';
ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS design_task_counter INTEGER DEFAULT 0;

-- ──────────────────────────────────────────
-- Design Task Assets (reference files / client briefs)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_task_assets (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id   UUID REFERENCES design_tasks(id) ON DELETE CASCADE NOT NULL,
    brand_id         UUID REFERENCES brands(id) ON DELETE CASCADE,
    file_name        TEXT NOT NULL,
    file_url         TEXT NOT NULL,
    file_type        TEXT,
    file_size        BIGINT,
    notes            TEXT,
    uploaded_by      UUID,
    uploaded_by_name TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_task_assets ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_task_assets' AND policyname = 'brand_access_design_task_assets'
    ) THEN
        CREATE POLICY "brand_access_design_task_assets" ON design_task_assets
            USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_task_assets' AND policyname = 'brand_write_design_task_assets'
    ) THEN
        CREATE POLICY "brand_write_design_task_assets" ON design_task_assets
            FOR ALL USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_design_task_assets_task  ON design_task_assets(design_task_id);
CREATE INDEX IF NOT EXISTS idx_design_task_assets_brand ON design_task_assets(brand_id);

-- ──────────────────────────────────────────
-- Design Task Delivery (final approved artwork files)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_task_delivery (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    design_task_id   UUID REFERENCES design_tasks(id) ON DELETE CASCADE NOT NULL,
    brand_id         UUID REFERENCES brands(id) ON DELETE CASCADE,
    file_name        TEXT NOT NULL,
    file_url         TEXT NOT NULL,
    file_type        TEXT,
    file_size        BIGINT,
    notes            TEXT,
    uploaded_by      UUID,
    uploaded_by_name TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE design_task_delivery ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_task_delivery' AND policyname = 'brand_access_design_task_delivery'
    ) THEN
        CREATE POLICY "brand_access_design_task_delivery" ON design_task_delivery
            USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_task_delivery' AND policyname = 'brand_write_design_task_delivery'
    ) THEN
        CREATE POLICY "brand_write_design_task_delivery" ON design_task_delivery
            FOR ALL USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_design_task_delivery_task  ON design_task_delivery(design_task_id);
CREATE INDEX IF NOT EXISTS idx_design_task_delivery_brand ON design_task_delivery(brand_id);

-- ──────────────────────────────────────────
-- RPC: atomic design task counter increment
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

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_design_tasks_brand  ON design_tasks(brand_id);
CREATE INDEX IF NOT EXISTS idx_design_tasks_club   ON design_tasks(club_id);
CREATE INDEX IF NOT EXISTS idx_design_tasks_due    ON design_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_design_tasks_status ON design_tasks(status);


-- ══════════════════════════════════════════════════════════════
-- SECTION 3: FIX 2 + 3 — Rewrite design_tasks & design_versions RLS
--
-- The original policies (migration 004) used:
--   USING (job_id IN (SELECT id FROM jobs WHERE brand_id IN (...)))
--
-- After migration 011 makes job_id optional, standalone tasks
-- (job_id IS NULL) evaluate to NULL (not TRUE) under this check
-- and are silently invisible to all users.
--
-- Fix: check brand_id directly first; fall back to job_id for
-- legacy job-linked tasks that may not have brand_id backfilled.
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- design_tasks RLS
-- ──────────────────────────────────────────
DROP POLICY IF EXISTS "brand_access_design_tasks" ON design_tasks;
DROP POLICY IF EXISTS "brand_write_design_tasks"  ON design_tasks;

CREATE POLICY "brand_access_design_tasks" ON design_tasks
    USING (
        brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (
                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
            )
        )
        OR
        job_id IN (
            SELECT id FROM jobs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );

CREATE POLICY "brand_write_design_tasks" ON design_tasks
    FOR ALL USING (
        brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (
                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
            )
        )
        OR
        job_id IN (
            SELECT id FROM jobs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );

-- ──────────────────────────────────────────
-- design_versions RLS
-- ──────────────────────────────────────────
DROP POLICY IF EXISTS "brand_access_design_versions" ON design_versions;
DROP POLICY IF EXISTS "brand_write_design_versions"  ON design_versions;

CREATE POLICY "brand_access_design_versions" ON design_versions
    USING (design_task_id IN (
        SELECT id FROM design_tasks
        WHERE
            brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
            OR
            job_id IN (
                SELECT id FROM jobs WHERE brand_id IN (
                    SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                    UNION
                    SELECT id FROM brands WHERE EXISTS (
                        SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                    )
                )
            )
    ));

CREATE POLICY "brand_write_design_versions" ON design_versions
    FOR ALL USING (design_task_id IN (
        SELECT id FROM design_tasks
        WHERE
            brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
            OR
            job_id IN (
                SELECT id FROM jobs WHERE brand_id IN (
                    SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                    UNION
                    SELECT id FROM brands WHERE EXISTS (
                        SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                    )
                )
            )
    ));


-- ══════════════════════════════════════════════════════════════
-- SECTION 4: FIX 4 — design_feed: add design_task_id
--
-- design_feed previously only linked via job_id.
-- Standalone design tasks (no job) need their own link so
-- feed entries can be created and surfaced correctly.
-- ══════════════════════════════════════════════════════════════
ALTER TABLE design_feed
    ADD COLUMN IF NOT EXISTS design_task_id UUID REFERENCES design_tasks(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_design_feed_task ON design_feed(design_task_id);


-- ══════════════════════════════════════════════════════════════
-- SECTION 5: FIX 5 + 6 — Supabase Security Linter Fixes
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- FIX 5a: Enable RLS on design_annotations
-- (table created in 006 without RLS — flagged CRITICAL)
-- Access is determined via: annotation → version → design_task → brand_id
-- ──────────────────────────────────────────
ALTER TABLE design_annotations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_annotations' AND policyname = 'brand_access_design_annotations'
    ) THEN
        CREATE POLICY "brand_access_design_annotations" ON design_annotations
            USING (version_id IN (
                SELECT id FROM design_versions
                WHERE design_task_id IN (
                    SELECT id FROM design_tasks
                    WHERE brand_id IN (
                        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                        UNION
                        SELECT id FROM brands WHERE EXISTS (
                            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                        )
                    )
                    OR job_id IN (
                        SELECT id FROM jobs WHERE brand_id IN (
                            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                            UNION
                            SELECT id FROM brands WHERE EXISTS (
                                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                            )
                        )
                    )
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_annotations' AND policyname = 'brand_write_design_annotations'
    ) THEN
        CREATE POLICY "brand_write_design_annotations" ON design_annotations
            FOR ALL USING (version_id IN (
                SELECT id FROM design_versions
                WHERE design_task_id IN (
                    SELECT id FROM design_tasks
                    WHERE brand_id IN (
                        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                        UNION
                        SELECT id FROM brands WHERE EXISTS (
                            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                        )
                    )
                    OR job_id IN (
                        SELECT id FROM jobs WHERE brand_id IN (
                            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                            UNION
                            SELECT id FROM brands WHERE EXISTS (
                                SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                            )
                        )
                    )
                )
            ));
    END IF;
END $$;

-- ──────────────────────────────────────────
-- FIX 5b: Enable RLS on design_feed
-- (table created in 006 without RLS — flagged CRITICAL)
-- After section 4, design_feed now has brand_id via job or design_task
-- ──────────────────────────────────────────
ALTER TABLE design_feed ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_feed' AND policyname = 'brand_access_design_feed'
    ) THEN
        CREATE POLICY "brand_access_design_feed" ON design_feed
            USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'design_feed' AND policyname = 'brand_write_design_feed'
    ) THEN
        CREATE POLICY "brand_write_design_feed" ON design_feed
            FOR ALL USING (brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            ));
    END IF;
END $$;

-- ──────────────────────────────────────────
-- FIX 6: Add SET search_path to all SECURITY DEFINER functions
-- Supabase flags functions without a fixed search_path as a
-- security risk (search_path injection). Fix: recreate each
-- function with SET search_path = '' and fully-qualified names.
-- ──────────────────────────────────────────

-- handle_new_user (009)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, role)
    VALUES (NEW.id, NEW.email, 'user')
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- get_next_job_number (004)
CREATE OR REPLACE FUNCTION public.get_next_job_number(p_brand_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    job_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO job_count FROM public.jobs WHERE brand_id = p_brand_id;
    RETURN 'JOB-' || LPAD((job_count + 1)::TEXT, 4, '0');
END;
$$;

-- update_updated_at_column (003/005)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- increment_design_task_counter (011/013)
CREATE OR REPLACE FUNCTION public.increment_design_task_counter(brand_id_input UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    new_counter INTEGER;
BEGIN
    UPDATE public.brands
    SET design_task_counter = COALESCE(design_task_counter, 0) + 1
    WHERE id = brand_id_input
    RETURNING design_task_counter INTO new_counter;
    RETURN new_counter;
END;
$$;

-- generate_po_number, get_user_brand_id, is_super_admin were created
-- manually in Supabase (not tracked in any migration file).
-- Use OID-based ALTER to fix search_path without needing their signatures.
DO $$
DECLARE
    func RECORD;
BEGIN
    FOR func IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('generate_po_number', 'get_user_brand_id', 'is_super_admin')
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = ''''', func.sig);
    END LOOP;
END $$;
