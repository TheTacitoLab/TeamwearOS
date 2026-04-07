-- =============================================
-- Migration 036: Kit Player Details
-- Adds product list and player personalisation tables for
-- the Order Hub customer-facing portal.
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- kit_products
-- Products copied from job_products when a hub link is generated.
-- Denormalised so the anon hub client can read them without
-- touching the auth-gated job_products / club_products tables.
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kit_products (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id         UUID REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
    club_product_id  UUID,                  -- original FK (not enforced — source table is auth-only)
    product_name     TEXT NOT NULL DEFAULT '',
    sizes            TEXT DEFAULT 'S,M,L,XL,2XL',  -- comma-separated size run
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE kit_products ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_kit_products_order_id ON kit_products(order_id);

DROP POLICY IF EXISTS "kit_products_auth_all" ON kit_products;
CREATE POLICY "kit_products_auth_all" ON kit_products
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "kit_products_anon_read" ON kit_products;
CREATE POLICY "kit_products_anon_read" ON kit_products
    FOR SELECT TO anon USING (true);

-- ──────────────────────────────────────────
-- kit_player_details
-- One row per player slot (product × size × player).
-- Customers fill these in on the Player Details page.
-- Anon users can read, insert, update and delete their own rows
-- (access is gated at the application layer by the hub token).
-- ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS kit_player_details (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id             UUID REFERENCES kit_orders(id) ON DELETE CASCADE NOT NULL,
    kit_product_id       UUID REFERENCES kit_products(id) ON DELETE CASCADE NOT NULL,
    product_name         TEXT,
    size                 TEXT,
    personalisation_type TEXT NOT NULL DEFAULT 'none',  -- name_number | number_only | initials_only | none
    player_name          TEXT,
    player_number        TEXT,
    player_initials      TEXT,
    line_order           INTEGER NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE kit_player_details ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_kit_player_details_order_id     ON kit_player_details(order_id);
CREATE INDEX IF NOT EXISTS idx_kit_player_details_kit_product  ON kit_player_details(kit_product_id);

DROP POLICY IF EXISTS "kit_player_details_auth_all" ON kit_player_details;
CREATE POLICY "kit_player_details_auth_all" ON kit_player_details
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "kit_player_details_anon_read" ON kit_player_details;
CREATE POLICY "kit_player_details_anon_read" ON kit_player_details
    FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "kit_player_details_anon_insert" ON kit_player_details;
CREATE POLICY "kit_player_details_anon_insert" ON kit_player_details
    FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "kit_player_details_anon_update" ON kit_player_details;
CREATE POLICY "kit_player_details_anon_update" ON kit_player_details
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "kit_player_details_anon_delete" ON kit_player_details;
CREATE POLICY "kit_player_details_anon_delete" ON kit_player_details
    FOR DELETE TO anon USING (true);
