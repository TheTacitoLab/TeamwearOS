-- Migration 059: Factory PO Tracker
-- New, simple factory-facing purchase order tracker. This is a brand-new
-- feature and is intentionally separate from the existing `purchase_orders`
-- table (which is shared by the Order Builder / PDF flow and dashboards).
--
-- Surfaces:
--   * Internal Factory tab in index.html (authenticated brand users)
--   * Public factory link factory/view.html (anon) — read + press "Shipped"

-- =============================================================
-- 1. Purchase orders
-- =============================================================
CREATE TABLE IF NOT EXISTS factory_purchase_orders (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id                    uuid REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    job_id                      uuid REFERENCES jobs(id) ON DELETE SET NULL,
    po_number                   text NOT NULL,
    po_seq                      integer,
    order_date                  date NOT NULL DEFAULT CURRENT_DATE,
    po_title                    text,
    club_id                     uuid REFERENCES clubs(id) ON DELETE SET NULL,
    club_name                   text,
    team_name                   text,
    assets_url                  text,
    delivery_due_date           date,
    -- Factory details / stages
    artwork_approved            boolean NOT NULL DEFAULT false,
    artwork_approved_date       date,
    pps_approved                boolean NOT NULL DEFAULT false,
    pps_approved_date           date,
    pps_url                     text,
    shipped                     boolean NOT NULL DEFAULT false,
    shipped_date                date,
    completion_status           text NOT NULL DEFAULT 'in_progress',  -- in_progress | part_completed | completed
    revised_delivery_requested  boolean NOT NULL DEFAULT false,
    revised_delivery_date       date,
    revised_delivery_notes      text,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    created_by                  uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_factory_pos_brand ON factory_purchase_orders(brand_id);
CREATE INDEX IF NOT EXISTS idx_factory_pos_job   ON factory_purchase_orders(job_id);

ALTER TABLE factory_purchase_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "factory_pos_auth" ON factory_purchase_orders;
CREATE POLICY "factory_pos_auth" ON factory_purchase_orders FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "factory_pos_anon_read" ON factory_purchase_orders;
CREATE POLICY "factory_pos_anon_read" ON factory_purchase_orders FOR SELECT TO anon USING (true);

-- Anon UPDATE so the factory can press "Shipped" on the public link.
-- Mirrors the existing fabric_stock_anon_update policy (migration 049).
DROP POLICY IF EXISTS "factory_pos_anon_update" ON factory_purchase_orders;
CREATE POLICY "factory_pos_anon_update" ON factory_purchase_orders FOR UPDATE TO anon
    USING (true) WITH CHECK (true);

-- =============================================================
-- 2. Shipping documents (mirrors design_task_assets)
-- =============================================================
CREATE TABLE IF NOT EXISTS factory_po_files (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id            uuid REFERENCES factory_purchase_orders(id) ON DELETE CASCADE NOT NULL,
    brand_id         uuid REFERENCES brands(id) ON DELETE CASCADE,
    file_name        text NOT NULL,
    file_url         text NOT NULL,
    file_type        text,
    file_size        bigint,
    uploaded_by      uuid,
    uploaded_by_name text,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_factory_po_files_po ON factory_po_files(po_id);

ALTER TABLE factory_po_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "factory_po_files_auth" ON factory_po_files;
CREATE POLICY "factory_po_files_auth" ON factory_po_files FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "factory_po_files_anon_read" ON factory_po_files;
CREATE POLICY "factory_po_files_anon_read" ON factory_po_files FOR SELECT TO anon USING (true);

-- =============================================================
-- 3. PO numbering settings on brands
-- =============================================================
ALTER TABLE brands ADD COLUMN IF NOT EXISTS po_prefix      text DEFAULT 'RP';
ALTER TABLE brands ADD COLUMN IF NOT EXISTS po_next_number integer DEFAULT 1;
