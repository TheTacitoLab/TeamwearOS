-- Migration 055: Product recipe available colours + per-club colour selections

-- 1. Replace single colour_hex / colour_pantone on product_fabric_recipes with an
--    array of available colours so a component can offer multiple colour options.
ALTER TABLE product_fabric_recipes
    ADD COLUMN IF NOT EXISTS available_colours jsonb DEFAULT '[]';

-- Migrate any existing single colour_hex → available_colours array
UPDATE product_fabric_recipes
SET available_colours = jsonb_build_array(
    jsonb_build_object(
        'hex',          colour_hex,
        'pantone_code', COALESCE(colour_pantone, '')
    )
)
WHERE colour_hex IS NOT NULL
  AND colour_hex <> ''
  AND (available_colours IS NULL OR available_colours = '[]'::jsonb);

-- 2. Per-club-product colour selection — which colour from the recipe's available
--    list does this specific club product use? Drives the fabric forecast engine.
CREATE TABLE IF NOT EXISTS club_product_colour_selections (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_product_id  uuid NOT NULL REFERENCES club_products(id) ON DELETE CASCADE,
    recipe_id        uuid NOT NULL REFERENCES product_fabric_recipes(id) ON DELETE CASCADE,
    colour_hex       text,
    colour_pantone   text,
    created_at       timestamptz DEFAULT now(),
    UNIQUE(club_product_id, recipe_id)
);
CREATE INDEX IF NOT EXISTS idx_cpcs_club_product
    ON club_product_colour_selections(club_product_id);

-- 3. RLS: brand users can manage their own clubs' colour selections
ALTER TABLE club_product_colour_selections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cpcs_brand_access" ON club_product_colour_selections;
CREATE POLICY "cpcs_brand_access" ON club_product_colour_selections
    FOR ALL TO authenticated
    USING (
        club_product_id IN (
            SELECT cp.id
            FROM   club_products cp
            JOIN   clubs c ON c.id = cp.club_id
            WHERE  c.brand_id IN (
                SELECT brand_id FROM user_profiles WHERE id = auth.uid()
                UNION
                SELECT id FROM brands
                WHERE  EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE  id = auth.uid() AND role = 'super_admin'
                )
            )
        )
    );

-- Anon read so the factory portal forecast can group demand by club colour choice
DROP POLICY IF EXISTS "cpcs_anon_read" ON club_product_colour_selections;
CREATE POLICY "cpcs_anon_read" ON club_product_colour_selections
    FOR SELECT TO anon USING (true);
