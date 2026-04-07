-- =============================================
-- Migration 035: Kit Order Hub
-- Customer-facing 3-stage approval hub linked from the Sales Job Record.
-- Stages: 1 = Concept Approval, 2 = Full Range Approval, 3 = Pre-Production Approval.
-- Stages 1 & 2 auto-unlock from the DTR approveStage() hook.
-- Stage 3 is uploaded manually by admin.
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- kit_orders
-- One record per Sales Job. Holds the unique URL token
-- and tracks which stages have been unlocked for the customer.
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kit_orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id              UUID REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
    brand_id            UUID REFERENCES brands(id) ON DELETE SET NULL,
    club_id             UUID REFERENCES clubs(id) ON DELETE SET NULL,
    token               TEXT UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
    status              TEXT NOT NULL DEFAULT 'active',   -- active | completed
    hub_url             TEXT,
    stage_1_unlocked    BOOLEAN NOT NULL DEFAULT false,
    stage_2_unlocked    BOOLEAN NOT NULL DEFAULT false,
    stage_3_unlocked    BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE kit_orders ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_kit_orders_job_id ON kit_orders(job_id);
CREATE INDEX IF NOT EXISTS idx_kit_orders_token  ON kit_orders(token);

-- Authenticated users (TeamwearOS admin/staff) — full access
DROP POLICY IF EXISTS "kit_orders_auth_all" ON kit_orders;
CREATE POLICY "kit_orders_auth_all" ON kit_orders
    FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- Anon (customer hub) — read only, access gated by token in application layer
DROP POLICY IF EXISTS "kit_orders_anon_read" ON kit_orders;
CREATE POLICY "kit_orders_anon_read" ON kit_orders
    FOR SELECT TO anon
    USING (true);

-- ──────────────────────────────────────────
-- kit_stage_files
-- Files displayed to the customer per stage.
-- Stages 1 & 2: populated automatically from stage_uploads when DTR stage is approved.
-- Stage 3:       uploaded manually by admin.
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kit_stage_files (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
    stage_number        INTEGER NOT NULL CHECK (stage_number IN (1, 2, 3)),
    file_url            TEXT NOT NULL,
    file_name           TEXT,
    file_type           TEXT,
    source              TEXT NOT NULL DEFAULT 'manual',  -- 'design_task' | 'manual'
    source_upload_id    UUID,                            -- FK to stage_uploads (stages 1 & 2 only)
    uploaded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE kit_stage_files ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_kit_stage_files_order_id ON kit_stage_files(order_id);

-- Authenticated — full access
DROP POLICY IF EXISTS "kit_stage_files_auth_all" ON kit_stage_files;
CREATE POLICY "kit_stage_files_auth_all" ON kit_stage_files
    FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- Anon — read only (customer views files)
DROP POLICY IF EXISTS "kit_stage_files_anon_read" ON kit_stage_files;
CREATE POLICY "kit_stage_files_anon_read" ON kit_stage_files
    FOR SELECT TO anon
    USING (true);

-- ──────────────────────────────────────────
-- kit_file_reviews
-- Customer approval decisions per file.
-- Anon users can INSERT and UPDATE (customer submits without auth).
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kit_file_reviews (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id       UUID REFERENCES kit_stage_files(id) ON DELETE CASCADE NOT NULL,
    order_id      UUID REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
    stage_number  INTEGER NOT NULL,
    decision      TEXT NOT NULL CHECK (decision IN ('approved', 'declined')),
    feedback      TEXT,
    reviewed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE kit_file_reviews ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_kit_file_reviews_order_id ON kit_file_reviews(order_id);
CREATE INDEX IF NOT EXISTS idx_kit_file_reviews_file_id  ON kit_file_reviews(file_id);

-- Authenticated — full access
DROP POLICY IF EXISTS "kit_file_reviews_auth_all" ON kit_file_reviews;
CREATE POLICY "kit_file_reviews_auth_all" ON kit_file_reviews
    FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- Anon — read (customer sees existing decisions)
DROP POLICY IF EXISTS "kit_file_reviews_anon_read" ON kit_file_reviews;
CREATE POLICY "kit_file_reviews_anon_read" ON kit_file_reviews
    FOR SELECT TO anon
    USING (true);

-- Anon — insert (customer submits new decision)
DROP POLICY IF EXISTS "kit_file_reviews_anon_insert" ON kit_file_reviews;
CREATE POLICY "kit_file_reviews_anon_insert" ON kit_file_reviews
    FOR INSERT TO anon
    WITH CHECK (true);

-- Anon — update (customer changes their decision)
DROP POLICY IF EXISTS "kit_file_reviews_anon_update" ON kit_file_reviews;
CREATE POLICY "kit_file_reviews_anon_update" ON kit_file_reviews
    FOR UPDATE TO anon
    USING (true) WITH CHECK (true);
