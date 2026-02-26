-- =============================================
-- Migration 007: Partnership Levels & Enhanced Product Features
-- =============================================

-- 1. Brand Pricing Tiers (replaces hardcoded retail/partner/partner_plus)
--    Each brand defines its own pricing levels (e.g. ROKOR: Retail, Partner, Partner+)
CREATE TABLE IF NOT EXISTS brand_pricing_tiers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    tier_key TEXT NOT NULL,        -- slug key e.g. 'retail', 'partner', 'partner_plus'
    tier_name TEXT NOT NULL,       -- display name e.g. 'Retail', 'Partner', 'Partner+'
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, tier_key)
);

-- 2. Per-product pricing per tier (JSONB on products for simplicity)
--    Format: {"retail": {"youth": 35.95, "adult": 42.95}, "partner": {"youth": 29.95, "adult": 35.95}}
ALTER TABLE products ADD COLUMN IF NOT EXISTS tier_prices JSONB DEFAULT '{}'::jsonb;

-- 3. Shopify Tags saved per brand (so they can be re-used)
CREATE TABLE IF NOT EXISTS brand_shopify_tags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    tag TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, tag)
);

-- 4. Shopify Tags on products (which saved tags are applied to this product)
ALTER TABLE products ADD COLUMN IF NOT EXISTS shopify_tags JSONB DEFAULT '[]'::jsonb;

-- 5. Salesperson assignment on clubs (must-have; also used as Shopify CSV tag)
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS assigned_salesperson_id UUID REFERENCES salespeople(id) ON DELETE SET NULL;

-- 6. Partnership tier IDs assigned to club (one or many price lists)
--    Stores array of tier_key strings e.g. ["retail", "partner"]
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS partnership_tier_keys JSONB DEFAULT '[]'::jsonb;

-- 7. Remove hardcoded CHECK constraint on club_status to allow custom tier names
--    (The constraint name varies, so we drop by discovering it first — safe with IF EXISTS approach)
DO $$
BEGIN
    -- Drop the constraint if it exists (name may vary across deployments)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'clubs'
          AND constraint_type = 'CHECK'
          AND constraint_name LIKE '%club_status%'
    ) THEN
        EXECUTE (
            SELECT 'ALTER TABLE clubs DROP CONSTRAINT ' || constraint_name
            FROM information_schema.table_constraints
            WHERE table_name = 'clubs'
              AND constraint_type = 'CHECK'
              AND constraint_name LIKE '%club_status%'
            LIMIT 1
        );
    END IF;
END $$;

-- =============================================
-- RLS Policies
-- =============================================

ALTER TABLE brand_pricing_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage pricing tiers for their brand" ON brand_pricing_tiers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.brand_id = brand_pricing_tiers.brand_id
              AND up.id = auth.uid()
        )
    );

ALTER TABLE brand_shopify_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage shopify tags for their brand" ON brand_shopify_tags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.brand_id = brand_shopify_tags.brand_id
              AND up.id = auth.uid()
        )
    );

-- =============================================
-- Seed default tiers for any existing brands
-- (Retail + Partner as safe defaults)
-- =============================================
INSERT INTO brand_pricing_tiers (brand_id, tier_key, tier_name, sort_order)
SELECT id, 'retail', 'Retail', 0 FROM brands
ON CONFLICT (brand_id, tier_key) DO NOTHING;

INSERT INTO brand_pricing_tiers (brand_id, tier_key, tier_name, sort_order)
SELECT id, 'partner', 'Partner', 1 FROM brands
ON CONFLICT (brand_id, tier_key) DO NOTHING;

-- Migrate existing pricing data into tier_prices JSONB
UPDATE products
SET tier_prices = jsonb_build_object(
    'retail', jsonb_build_object(
        'youth', COALESCE(youth_retail_price::text, 'null')::jsonb,
        'adult', COALESCE(adult_retail_price::text, 'null')::jsonb
    ),
    'partner', jsonb_build_object(
        'youth', COALESCE(youth_partner_price::text, 'null')::jsonb,
        'adult', COALESCE(adult_partner_price::text, 'null')::jsonb
    )
)
WHERE tier_prices = '{}'::jsonb
  AND (youth_retail_price IS NOT NULL OR adult_retail_price IS NOT NULL);
