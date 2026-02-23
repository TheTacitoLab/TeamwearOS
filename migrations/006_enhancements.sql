-- ══════════════════════════════════════════════════════════════
-- 006_enhancements.sql
-- Multi-select products, club jobs tab, pantone codes,
-- design annotations, design stage on jobs
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- Pantone reference codes (separate from hex colours)
-- ──────────────────────────────────────────
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS pantone_main_code TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS pantone_sec_code  TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS pantone_acc_code  TEXT;

-- ──────────────────────────────────────────
-- Design stage on jobs (separate from job pipeline stage)
-- ──────────────────────────────────────────
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS design_stage TEXT DEFAULT 'not_started';

-- ──────────────────────────────────────────
-- File URL on design versions (actual image upload)
-- ──────────────────────────────────────────
ALTER TABLE design_versions ADD COLUMN IF NOT EXISTS file_url       TEXT;
ALTER TABLE design_versions ADD COLUMN IF NOT EXISTS storage_path   TEXT;

-- ──────────────────────────────────────────
-- Design annotations (clickable markers on a version image)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_annotations (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    version_id   UUID REFERENCES design_versions(id) ON DELETE CASCADE,
    marker_label TEXT        NOT NULL,  -- A, B, C, D ...
    x_percent    NUMERIC(6,3) NOT NULL, -- 0–100 % from left
    y_percent    NUMERIC(6,3) NOT NULL, -- 0–100 % from top
    comment      TEXT,
    created_by   UUID REFERENCES auth.users(id),
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- Design activity feed (dismissable per user)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS design_feed (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id      UUID REFERENCES brands(id) ON DELETE CASCADE,
    job_id        UUID REFERENCES jobs(id) ON DELETE CASCADE,
    version_id    UUID REFERENCES design_versions(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL, -- 'upload', 'annotation', 'approved', 'declined', 'status_change'
    message       TEXT,
    created_by    UUID REFERENCES auth.users(id),
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Array of user IDs who dismissed this feed item
ALTER TABLE design_feed ADD COLUMN IF NOT EXISTS dismissed_by UUID[] DEFAULT '{}';

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_design_feed_brand ON design_feed(brand_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_design_annotations_version ON design_annotations(version_id);
