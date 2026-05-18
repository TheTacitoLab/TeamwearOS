-- Factory Module: fabrics, product recipes, club forecast settings

-- 1. Fabric library (brand-scoped)
CREATE TABLE IF NOT EXISTS fabrics (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id       uuid NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
    fabric_name    text NOT NULL,
    construction   text,
    gsm            integer,
    colours        text[],
    notes          text,
    status         text DEFAULT 'active',
    supplier       text,
    fabric_width   numeric(6,2),
    cost_per_kg    numeric(10,2),
    min_order_qty  numeric(10,2),
    lead_time_days integer,
    created_at     timestamptz DEFAULT now(),
    updated_at     timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fabrics_brand ON fabrics(brand_id);

-- 2. Total fabric weight on master products
ALTER TABLE products ADD COLUMN IF NOT EXISTS total_fabric_kg numeric(8,4);

-- 3. Per-product fabric recipe
CREATE TABLE IF NOT EXISTS product_fabric_recipes (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id     uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    fabric_id      uuid NOT NULL REFERENCES fabrics(id) ON DELETE RESTRICT,
    component_type text NOT NULL,
    allocation_pct numeric(5,2) NOT NULL,
    sort_order     integer DEFAULT 0,
    created_at     timestamptz DEFAULT now(),
    UNIQUE (product_id, component_type)
);
CREATE INDEX IF NOT EXISTS idx_pfr_product ON product_fabric_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_pfr_fabric  ON product_fabric_recipes(fabric_id);

-- 4. Club forecast fields
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS number_of_teams          integer;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS number_of_players        integer;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS fabric_forecast_enabled  boolean DEFAULT false;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS fabric_forecast_due_date date;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS fabric_forecast_min_pct  numeric(5,2) DEFAULT 20;
