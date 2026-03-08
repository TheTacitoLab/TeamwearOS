-- ══════════════════════════════════════════════════════════════
-- 020_product_overhaul.sql
-- Master Product, Club Product & Shopify CSV overhaul
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- Products: Shopify & product structure fields
-- ──────────────────────────────────────────
ALTER TABLE products
    -- Shopify liquid template override (e.g. 'product.teamwear')
    ADD COLUMN IF NOT EXISTS shopify_template_suffix   TEXT,
    -- Shopify standardised product category (e.g. 'Apparel & Accessories > Clothing > Activewear')
    ADD COLUMN IF NOT EXISTS shopify_product_category  TEXT,
    -- Made-to-order flag: controls Inventory Policy in CSV (continue = TRUE, deny = FALSE)
    ADD COLUMN IF NOT EXISTS is_made_to_order          BOOLEAN DEFAULT TRUE;

-- ──────────────────────────────────────────
-- Brands: vendor name override for Shopify
-- ──────────────────────────────────────────
ALTER TABLE brands
    -- Override the Vendor column in Shopify CSV (defaults to brand name if null)
    ADD COLUMN IF NOT EXISTS shopify_vendor_name TEXT;

-- ──────────────────────────────────────────
-- tier_prices JSONB structure reference (no schema change — just documentation)
-- Extended format now supports:
-- {
--   "retail": {
--     "adult":           42.95,
--     "youth":           35.95,
--     "women":           42.95,      ← new
--     "one_size":        12.95,      ← new (replaces is_single_price / single_retail_price)
--     "compare_at_adult": 49.95,    ← new (optional)
--     "compare_at_youth": 42.95,    ← new (optional)
--     "compare_at_women": 49.95     ← new (optional)
--   },
--   "partner": { ... }
-- }
-- available_fits now supports: adult, youth, women, one_size
-- ──────────────────────────────────────────

-- Ensure clubs have a pricing_tier field (master switch for quoting & CSV export)
-- club_status already exists and serves this purpose — no change needed.

-- ──────────────────────────────────────────
-- club_products: store custom description
-- ──────────────────────────────────────────
ALTER TABLE club_products
    -- Stores the club-specific resolved description (placeholders filled)
    ADD COLUMN IF NOT EXISTS custom_description TEXT;

-- ──────────────────────────────────────────
-- Index for new fields
-- ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_products_is_made_to_order
    ON products(brand_id, is_made_to_order);
