-- Migration 060: Factory PO notes/chat + part-shipped milestone + read tracking
-- Adds a two-way notes thread per PO (factory ↔ brand), a part-shipped
-- milestone date so both part-ship and full-ship can be timed against the
-- deadline, and per-side last-read timestamps to drive the unread beacon.

-- 1. New columns on factory_purchase_orders
ALTER TABLE factory_purchase_orders ADD COLUMN IF NOT EXISTS part_shipped_date    date;
ALTER TABLE factory_purchase_orders ADD COLUMN IF NOT EXISTS brand_last_read_at   timestamptz;
ALTER TABLE factory_purchase_orders ADD COLUMN IF NOT EXISTS factory_last_read_at timestamptz;

-- 2. Notes thread
CREATE TABLE IF NOT EXISTS factory_po_notes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id       uuid REFERENCES factory_purchase_orders(id) ON DELETE CASCADE NOT NULL,
    brand_id    uuid REFERENCES brands(id) ON DELETE CASCADE,
    author_type text NOT NULL,            -- 'factory' | 'brand'
    author_name text,
    body        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_factory_po_notes_po ON factory_po_notes(po_id);

ALTER TABLE factory_po_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "factory_po_notes_auth" ON factory_po_notes;
CREATE POLICY "factory_po_notes_auth" ON factory_po_notes FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "factory_po_notes_anon_read" ON factory_po_notes;
CREATE POLICY "factory_po_notes_anon_read" ON factory_po_notes FOR SELECT TO anon USING (true);

-- Factory (anon, via the public link) can post notes
DROP POLICY IF EXISTS "factory_po_notes_anon_insert" ON factory_po_notes;
CREATE POLICY "factory_po_notes_anon_insert" ON factory_po_notes FOR INSERT TO anon WITH CHECK (true);
