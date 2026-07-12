-- Migration 067: Sub-brands
-- Simple named tags that sit under a brand. Any record can optionally be
-- assigned to one sub-brand; an unassigned record belongs to the main brand.
-- For now only Sales Job records (jobs), Design Tasks and Customer records
-- (clubs) can be tagged.
--
-- `brand_id` already exists on all three tables and is reserved for
-- multi-tenant RLS scoping, so a separate `sub_brand_id` column is required.

CREATE TABLE IF NOT EXISTS sub_brands (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id   uuid REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    name       text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sub_brands_brand ON sub_brands(brand_id);

ALTER TABLE sub_brands ENABLE ROW LEVEL SECURITY;

-- Matches the permissive factory-table policy style (059); brand scoping is
-- enforced by the client queries via brand_id.
DROP POLICY IF EXISTS "sub_brands_auth" ON sub_brands;
CREATE POLICY "sub_brands_auth" ON sub_brands FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "sub_brands_anon_read" ON sub_brands;
CREATE POLICY "sub_brands_anon_read" ON sub_brands FOR SELECT TO anon USING (true);

-- Optional sub-brand assignment on the three record types
ALTER TABLE jobs         ADD COLUMN IF NOT EXISTS sub_brand_id uuid REFERENCES sub_brands(id) ON DELETE SET NULL;
ALTER TABLE design_tasks ADD COLUMN IF NOT EXISTS sub_brand_id uuid REFERENCES sub_brands(id) ON DELETE SET NULL;
ALTER TABLE clubs        ADD COLUMN IF NOT EXISTS sub_brand_id uuid REFERENCES sub_brands(id) ON DELETE SET NULL;
