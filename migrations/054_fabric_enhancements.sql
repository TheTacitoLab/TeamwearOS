-- Migration 054: Fabric table enhancements — tags, sort order, GSM range

-- 1. Tags (free-form JSON array of strings)
ALTER TABLE fabrics ADD COLUMN IF NOT EXISTS tags jsonb DEFAULT '[]';

-- 2. Manual sort order (lower = higher in the list)
ALTER TABLE fabrics ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

-- Seed sort_order from current alphabetical order per brand so existing ordering
-- is preserved after the migration runs.
UPDATE fabrics f
SET sort_order = sub.rn
FROM (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY brand_id ORDER BY fabric_name) AS rn
    FROM fabrics
) sub
WHERE f.id = sub.id;

-- 3. GSM range (replaces single gsm integer — old column kept for backward compat)
ALTER TABLE fabrics ADD COLUMN IF NOT EXISTS gsm_min integer;
ALTER TABLE fabrics ADD COLUMN IF NOT EXISTS gsm_max integer;

-- Migrate existing single gsm value to both ends of the range
UPDATE fabrics SET gsm_min = gsm, gsm_max = gsm WHERE gsm IS NOT NULL;
