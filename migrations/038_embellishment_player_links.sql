-- Migration 038: Embellishment selection, player links, hub title
-- Adds:
--   kit_orders.hub_title           — display title (pre-filled from job_name)
--   kit_orders.player_order_token  — unique token for all-products player link
--   kit_products.allowed_personalisation_types — comma-separated list of allowed types per product
--   kit_products.product_player_token          — unique token for per-product player link

ALTER TABLE kit_orders
    ADD COLUMN IF NOT EXISTS hub_title TEXT,
    ADD COLUMN IF NOT EXISTS player_order_token TEXT UNIQUE;

ALTER TABLE kit_products
    ADD COLUMN IF NOT EXISTS allowed_personalisation_types TEXT
        DEFAULT 'none,name_number,number_only,initials_only',
    ADD COLUMN IF NOT EXISTS product_player_token TEXT UNIQUE;
