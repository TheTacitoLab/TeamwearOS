-- Migration 064: Anon read policies for clubs + products (factory forecast)
--
-- The Fabric Forecast tab on the public, token-gated factory/view.html portal
-- computes demand from clubs and their products. Migration 053 added anon read
-- for club_products / product_fabric_recipes / order_submission_items, and 057
-- added jobs / job_products, but the forecast ALSO reads `clubs` directly and
-- embeds `products` via PostgREST joins. Without anon SELECT on these two
-- tables a logged-out factory visitor gets zero clubs back, so the forecast
-- returns early and the tab appears empty. (Authenticated users see it fine
-- because their session is reused, which masked the gap.)
--
-- Security model: identical to migration 053 — the fabric_view_token in the URL
-- is the credential; the same USING (true) anon-read pattern already applies to
-- fabrics, fabric_stock, club_products, jobs, etc.

-- 1. clubs — queried directly to resolve the brand's club list + forecast config.
DROP POLICY IF EXISTS "clubs_anon_read" ON clubs;
CREATE POLICY "clubs_anon_read" ON clubs
    FOR SELECT TO anon USING (true);

-- 2. products — embedded in the club_products / job_products joins
--    (item_name, total_fabric_kg, product_fabric_recipes).
DROP POLICY IF EXISTS "products_anon_read" ON products;
CREATE POLICY "products_anon_read" ON products
    FOR SELECT TO anon USING (true);
