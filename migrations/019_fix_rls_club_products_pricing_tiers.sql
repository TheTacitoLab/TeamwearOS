-- =============================================
-- Migration 019: Fix RLS for club_products and brand_pricing_tiers
-- TeamwearOS
--
-- The original policies (migrations 001 and 008) used a simplified
-- EXISTS pattern that:
--   1. Lacks the super_admin bypass — users with role='super_admin'
--      and brand_id=NULL are incorrectly blocked on INSERT/UPDATE.
--   2. Uses a single FOR ALL policy instead of the standard read/write
--      split used consistently across migrations 005-018.
--
-- Fix: drop and rewrite both policies to match the established pattern.
-- =============================================


-- ──────────────────────────────────────────
-- club_products RLS
-- (no brand_id column — lookup via clubs table)
-- ──────────────────────────────────────────
DROP POLICY IF EXISTS "Users can manage club_products for their brand" ON club_products;

CREATE POLICY "brand_access_club_products" ON club_products
    USING (
        club_id IN (
            SELECT id FROM clubs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );

CREATE POLICY "brand_write_club_products" ON club_products
    FOR ALL USING (
        club_id IN (
            SELECT id FROM clubs WHERE brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands WHERE EXISTS (
                    SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );


-- ──────────────────────────────────────────
-- brand_pricing_tiers RLS
-- (has brand_id directly — straightforward lookup)
-- ──────────────────────────────────────────
DROP POLICY IF EXISTS "Users can manage pricing tiers for their brand" ON brand_pricing_tiers;

CREATE POLICY "brand_access_pricing_tiers" ON brand_pricing_tiers
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY "brand_write_pricing_tiers" ON brand_pricing_tiers
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));
