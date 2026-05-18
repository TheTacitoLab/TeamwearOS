-- Migration 049: Factory module phase 2 — structured colours, stock tracking, public share

-- 1. Structured colour storage on fabrics (jsonb array of {hex, pantone_code})
ALTER TABLE fabrics ADD COLUMN IF NOT EXISTS colour_options jsonb DEFAULT '[]';

-- Migrate any existing plain-text colours into colour_options
UPDATE fabrics
SET colour_options = (
    SELECT jsonb_agg(jsonb_build_object('hex', '#cccccc', 'pantone_code', c))
    FROM unnest(colours) AS c
)
WHERE colours IS NOT NULL
  AND array_length(colours, 1) > 0
  AND (colour_options IS NULL OR colour_options = '[]'::jsonb);

-- 2. Colour tracking on fabric recipe rows
ALTER TABLE product_fabric_recipes ADD COLUMN IF NOT EXISTS colour_hex     text;
ALTER TABLE product_fabric_recipes ADD COLUMN IF NOT EXISTS colour_pantone text;

-- 3. Fabric stock per colour
CREATE TABLE IF NOT EXISTS fabric_stock (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id                uuid NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
    fabric_id               uuid NOT NULL REFERENCES fabrics(id) ON DELETE CASCADE,
    colour_hex              text,
    colour_pantone          text,
    live_stock_kg           numeric(10,2) DEFAULT 0,
    kg_ordered              numeric(10,2),
    date_expected_in_stock  date,
    updated_at              timestamptz DEFAULT now(),
    UNIQUE (fabric_id, colour_hex)
);
CREATE INDEX IF NOT EXISTS idx_fabric_stock_brand  ON fabric_stock(brand_id);
CREATE INDEX IF NOT EXISTS idx_fabric_stock_fabric ON fabric_stock(fabric_id);

-- 4. Brand-level shareable token for public stock view
ALTER TABLE brands ADD COLUMN IF NOT EXISTS fabric_view_token text DEFAULT gen_random_uuid()::text;

-- Populate token for existing brands that don't have one
UPDATE brands SET fabric_view_token = gen_random_uuid()::text WHERE fabric_view_token IS NULL;

-- 5. RLS on fabric_stock
ALTER TABLE fabric_stock ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fabric_stock_auth" ON fabric_stock FOR ALL TO authenticated
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (
            SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin'
        )
    ));

CREATE POLICY "fabric_stock_anon_read"   ON fabric_stock FOR SELECT TO anon USING (true);
CREATE POLICY "fabric_stock_anon_update" ON fabric_stock FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "fabric_stock_anon_insert" ON fabric_stock FOR INSERT TO anon WITH CHECK (true);

-- 6. Anon read on fabrics (needed for public stock view)
CREATE POLICY "fabrics_anon_read" ON fabrics FOR SELECT TO anon USING (true);
