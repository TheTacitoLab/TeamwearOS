-- Migration 041: Add variant_name and listing_number to club_products
-- variant_name: stores the named label for V2+ variants and P2+ standalone listings
--               (e.g. "Red", "Home", "Away") — appended to the product title in CSV exports.
-- listing_number: distinguishes standalone product listings (P2, P3…) from the primary listing (1).
--                 Unlike variant_number, P2+ listings are treated as fully separate Shopify products.

ALTER TABLE club_products
    ADD COLUMN IF NOT EXISTS variant_name    TEXT,
    ADD COLUMN IF NOT EXISTS listing_number  INT NOT NULL DEFAULT 1;

-- Backfill existing rows so the unique index below is consistent
UPDATE club_products SET listing_number = 1 WHERE listing_number IS NULL;

-- Drop the previous unique index (covered only club_id, product_id, variant_number)
DROP INDEX IF EXISTS club_products_club_product_variant;

-- New unique index includes listing_number, allowing P2/P3 standalone listings to
-- coexist with the primary listing (listing_number = 1) for the same product.
CREATE UNIQUE INDEX IF NOT EXISTS club_products_club_product_variant
    ON club_products(club_id, product_id, variant_number, listing_number);
