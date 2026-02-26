-- ══════════════════════════════════════════════════════════════
-- 007_shopify_store_creator.sql
-- Extends products & club_products for the Shopify store creator
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- Master products: new fields
-- ──────────────────────────────────────────
ALTER TABLE products
    ADD COLUMN IF NOT EXISTS shopify_tags         TEXT,          -- custom tags for Shopify
    ADD COLUMN IF NOT EXISTS is_taxable           BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS cogs                 DECIMAL(10,2), -- cost of goods sold
    ADD COLUMN IF NOT EXISTS youth_sizes          TEXT,          -- comma-sep e.g. YXXS,YXS,YS,YM,YL,YXL
    ADD COLUMN IF NOT EXISTS women_retail_price   DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS women_partner_price  DECIMAL(10,2),
    ADD COLUMN IF NOT EXISTS women_sizes          TEXT,          -- comma-sep e.g. XS,S,M,L,XL
    ADD COLUMN IF NOT EXISTS available_fits       TEXT DEFAULT 'adult,youth'; -- adult,youth,women

-- ──────────────────────────────────────────
-- Club products: support multi-image and variants
-- ──────────────────────────────────────────
-- Drop old unique constraint so we can have V1/V2 variants
ALTER TABLE club_products DROP CONSTRAINT IF EXISTS club_products_club_id_product_id_key;

-- Add variant support + image array
ALTER TABLE club_products
    ADD COLUMN IF NOT EXISTS variant_number INT     DEFAULT 1,
    ADD COLUMN IF NOT EXISTS image_urls     JSONB   DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS has_image      BOOLEAN GENERATED ALWAYS AS (jsonb_array_length(image_urls) > 0) STORED;

-- New unique constraint allows V1/V2 etc.
CREATE UNIQUE INDEX IF NOT EXISTS club_products_club_product_variant
    ON club_products(club_id, product_id, variant_number);

-- Index for fast image lookups
CREATE INDEX IF NOT EXISTS idx_club_products_has_image
    ON club_products(club_id, has_image);

-- ──────────────────────────────────────────
-- Brands: toggle Shopify API on/off per brand
-- ──────────────────────────────────────────
ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS shopify_api_enabled BOOLEAN DEFAULT FALSE;
