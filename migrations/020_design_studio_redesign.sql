-- =============================================
-- Migration 020: Design Studio Redesign
-- Progressive 4-stage designer workflow
-- Stages: Brief → Concepts → Full Range → Final Artwork
-- With versioned uploads, annotations, and activity feed
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Extend design_tasks with richer brief fields
-- ──────────────────────────────────────────

ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS sport text;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS product_type text;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS colour_palette text;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS kit_details text;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS key_notes text;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS brief_attachments jsonb DEFAULT '[]';

-- ──────────────────────────────────────────
-- design_stages: tracks each of the 4 stages per task
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS design_stages (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id       uuid NOT NULL REFERENCES design_tasks(id) ON DELETE CASCADE,
    brand_id      uuid REFERENCES brands(id) ON DELETE CASCADE,
    stage_number  int NOT NULL CHECK (stage_number BETWEEN 1 AND 4),
    stage_name    text NOT NULL,
    status        text NOT NULL DEFAULT 'not_started'
        CHECK (status IN (
            'not_started','in_progress','in_review',
            'revisions_required','approved','declined','skipped'
        )),
    is_skipped    boolean DEFAULT false,
    completed_at  timestamptz,
    completed_by  uuid REFERENCES auth.users(id),
    created_at    timestamptz DEFAULT now(),
    updated_at    timestamptz DEFAULT now(),
    UNIQUE (task_id, stage_number)
);

ALTER TABLE design_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_design_stages" ON design_stages
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_design_stages" ON design_stages
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_design_stages_task   ON design_stages(task_id);
CREATE INDEX IF NOT EXISTS idx_design_stages_brand  ON design_stages(brand_id);
CREATE INDEX IF NOT EXISTS idx_design_stages_status ON design_stages(status);

-- ──────────────────────────────────────────
-- stage_status_log: history of status changes per stage
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stage_status_log (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    stage_id         uuid NOT NULL REFERENCES design_stages(id) ON DELETE CASCADE,
    task_id          uuid NOT NULL REFERENCES design_tasks(id) ON DELETE CASCADE,
    brand_id         uuid REFERENCES brands(id),
    actor_id         uuid REFERENCES auth.users(id),
    actor_name       text,
    previous_status  text,
    new_status       text NOT NULL,
    comment          text,
    created_at       timestamptz DEFAULT now()
);

ALTER TABLE stage_status_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_stage_status_log" ON stage_status_log
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_stage_status_log" ON stage_status_log
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_stage_status_log_stage  ON stage_status_log(stage_id);
CREATE INDEX IF NOT EXISTS idx_stage_status_log_task   ON stage_status_log(task_id);
CREATE INDEX IF NOT EXISTS idx_stage_status_log_brand  ON stage_status_log(brand_id);

-- ──────────────────────────────────────────
-- stage_uploads: versioned file uploads per stage
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stage_uploads (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    stage_id       uuid NOT NULL REFERENCES design_stages(id) ON DELETE CASCADE,
    task_id        uuid NOT NULL REFERENCES design_tasks(id) ON DELETE CASCADE,
    brand_id       uuid REFERENCES brands(id),
    section_label  text,        -- used by Stage 4: 'print_files','full_range_pdf','tech_pack','website_imagery'
    version_label  text NOT NULL, -- 'V1','V2'... or same as section_label for Stage 4
    file_url       text NOT NULL,
    file_name      text,
    file_type      text,
    file_size      bigint,
    status         text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','approved','declined')),
    uploaded_by    uuid REFERENCES auth.users(id),
    uploaded_by_name text,
    uploaded_at    timestamptz DEFAULT now(),
    review_comment text
);

ALTER TABLE stage_uploads ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_stage_uploads" ON stage_uploads
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_stage_uploads" ON stage_uploads
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_stage_uploads_stage  ON stage_uploads(stage_id);
CREATE INDEX IF NOT EXISTS idx_stage_uploads_task   ON stage_uploads(task_id);
CREATE INDEX IF NOT EXISTS idx_stage_uploads_brand  ON stage_uploads(brand_id);

-- ──────────────────────────────────────────
-- upload_annotations: pin annotations on uploaded files
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS upload_annotations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    upload_id   uuid NOT NULL REFERENCES stage_uploads(id) ON DELETE CASCADE,
    brand_id    uuid REFERENCES brands(id),
    actor_id    uuid REFERENCES auth.users(id),
    actor_name  text,
    x_position  numeric NOT NULL, -- percentage 0–100 of container width
    y_position  numeric NOT NULL, -- percentage 0–100 of container height
    page_number int DEFAULT 1,
    comment     text NOT NULL,
    pin_number  int,
    created_at  timestamptz DEFAULT now()
);

ALTER TABLE upload_annotations ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_upload_annotations" ON upload_annotations
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_upload_annotations" ON upload_annotations
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_upload_annotations_upload ON upload_annotations(upload_id);
CREATE INDEX IF NOT EXISTS idx_upload_annotations_brand  ON upload_annotations(brand_id);

-- ──────────────────────────────────────────
-- design_activity_feed: global per-brand activity stream
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS design_activity_feed (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id       uuid NOT NULL REFERENCES design_tasks(id) ON DELETE CASCADE,
    stage_id      uuid REFERENCES design_stages(id) ON DELETE SET NULL,
    brand_id      uuid REFERENCES brands(id),
    actor_id      uuid REFERENCES auth.users(id),
    actor_name    text,
    action_type   text NOT NULL,
    -- action_type values: task_created, stage_accepted, stage_declined,
    --   stage_needs_info, version_uploaded, version_approved, version_declined,
    --   stage_submitted_for_review, stage_approved, stage_revisions_requested,
    --   stage_skipped, task_completed
    action_detail jsonb DEFAULT '{}',
    is_read       boolean DEFAULT false,
    created_at    timestamptz DEFAULT now()
);

ALTER TABLE design_activity_feed ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "brand_read_design_activity_feed" ON design_activity_feed
    FOR SELECT USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY IF NOT EXISTS "brand_write_design_activity_feed" ON design_activity_feed
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE INDEX IF NOT EXISTS idx_design_activity_feed_task    ON design_activity_feed(task_id);
CREATE INDEX IF NOT EXISTS idx_design_activity_feed_brand   ON design_activity_feed(brand_id);
CREATE INDEX IF NOT EXISTS idx_design_activity_feed_created ON design_activity_feed(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_design_activity_feed_unread  ON design_activity_feed(brand_id, is_read) WHERE is_read = false;

-- ──────────────────────────────────────────
-- Trigger: auto-create 4 stage rows when a design task is inserted
-- ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_design_stages_on_task_insert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO design_stages (task_id, brand_id, stage_number, stage_name, status)
    VALUES
        (NEW.id, NEW.brand_id, 1, 'Brief',        'not_started'),
        (NEW.id, NEW.brand_id, 2, 'Concepts',     'not_started'),
        (NEW.id, NEW.brand_id, 3, 'Full Range',   'not_started'),
        (NEW.id, NEW.brand_id, 4, 'Final Artwork','not_started')
    ON CONFLICT (task_id, stage_number) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_design_stages ON design_tasks;

CREATE TRIGGER trg_create_design_stages
    AFTER INSERT ON design_tasks
    FOR EACH ROW
    EXECUTE FUNCTION create_design_stages_on_task_insert();

-- ──────────────────────────────────────────
-- Backfill: create stage rows for existing tasks that don't have them yet
-- ──────────────────────────────────────────

INSERT INTO design_stages (task_id, brand_id, stage_number, stage_name, status)
SELECT
    dt.id,
    dt.brand_id,
    s.stage_number,
    s.stage_name,
    'not_started'
FROM design_tasks dt
CROSS JOIN (VALUES
    (1, 'Brief'),
    (2, 'Concepts'),
    (3, 'Full Range'),
    (4, 'Final Artwork')
) AS s(stage_number, stage_name)
WHERE dt.brand_id IS NOT NULL
ON CONFLICT (task_id, stage_number) DO NOTHING;

-- ──────────────────────────────────────────
-- Performance indexes
-- ──────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_design_stages_updated ON design_stages(updated_at DESC);
