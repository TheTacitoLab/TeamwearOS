-- Migration 014: Configurable SKU template per brand
--
-- Each brand can define their own SKU format using token placeholders.
-- The default value matches the existing hardcoded formula exactly,
-- so all existing brands are unaffected with zero output change.
--
-- Available tokens (resolved at runtime by buildSku() in index.html):
--   {product_code}  — the master product's product_code field
--   {club_suffix}   — the club's suffix/abbreviation
--   {size}          — the variant size (XL, YM, OS, etc.)
--   {range_name}    — the product's range_name field
--   {category}      — the product's category field

ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS sku_template TEXT DEFAULT '{product_code}/{club_suffix}-{size}';
