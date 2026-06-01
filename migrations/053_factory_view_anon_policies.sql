-- Migration 053: Anon read policies for factory/view.html portal
--
-- factory/view.html is a public, token-gated page served to factory staff.
-- It uses the Supabase anon key (no login). Without these policies the brand
-- lookup by fabric_view_token fails immediately, showing "Link not found or
-- expired" to every non-authenticated visitor.
--
-- Security model: the fabric_view_token in the URL acts as the credential.
-- The same USING (true) pattern is used for kit_orders, kit_stage_files, etc.

-- 1. brands — anon needs to look up the brand row by fabric_view_token.
--    Enable RLS (idempotent) then add an authenticated catch-all so existing
--    in-app access is preserved when RLS is first switched on.
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "brands_authenticated_access" ON brands;
CREATE POLICY "brands_authenticated_access" ON brands
    FOR ALL TO authenticated
    USING (
        id IN (SELECT brand_id FROM user_profiles WHERE id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

DROP POLICY IF EXISTS "brands_anon_read" ON brands;
CREATE POLICY "brands_anon_read" ON brands
    FOR SELECT TO anon USING (true);

-- 2. club_products — RLS enabled in migration 001, authenticated-only.
--    Anon needs SELECT for the forecast tab (embedded join from club_products).
DROP POLICY IF EXISTS "club_products_anon_read" ON club_products;
CREATE POLICY "club_products_anon_read" ON club_products
    FOR SELECT TO anon USING (true);

-- 3. product_fabric_recipes — RLS enabled in migration 048, authenticated-only.
--    Anon needs SELECT for the embedded recipe join in the forecast tab.
DROP POLICY IF EXISTS "product_fabric_recipes_anon_read" ON product_fabric_recipes;
CREATE POLICY "product_fabric_recipes_anon_read" ON product_fabric_recipes
    FOR SELECT TO anon USING (true);

-- 4. order_submission_items — RLS enabled in migration 001 (anon can INSERT
--    but not SELECT). Anon needs SELECT to add live order quantities to the
--    forecast view.
DROP POLICY IF EXISTS "order_submission_items_anon_read" ON order_submission_items;
CREATE POLICY "order_submission_items_anon_read" ON order_submission_items
    FOR SELECT TO anon USING (true);
