-- RLS policies for Factory module tables (matches project pattern from migration 004)

ALTER TABLE fabrics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "brand_access_fabrics" ON fabrics;
CREATE POLICY "brand_access_fabrics" ON fabrics
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));

ALTER TABLE product_fabric_recipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "brand_access_product_fabric_recipes" ON product_fabric_recipes;
CREATE POLICY "brand_access_product_fabric_recipes" ON product_fabric_recipes
    FOR ALL USING (product_id IN (
        SELECT id FROM products WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));
