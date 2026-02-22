-- ============================================================
-- TeamwearOS PO Tracker V2 Migration
-- Run these in your Supabase SQL Editor
-- ============================================================

-- ----------------------------------------
-- 1. Extend purchase_orders table
-- ----------------------------------------
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS factory_name TEXT;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS shopify_order_ids JSONB DEFAULT '[]';
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS expected_delivery_date DATE;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id) ON DELETE SET NULL;

-- Update status column to support richer values
-- (Existing: 'draft', 'sent', 'acknowledged', 'in_production', 'shipped', 'delivered', 'cancelled')
-- If status column already exists as TEXT, no schema change needed — just use new values in app.
-- If it was an ENUM, you'd need to add values. Assuming TEXT column:
-- ALTER TABLE purchase_orders ALTER COLUMN status SET DEFAULT 'draft';

-- ----------------------------------------
-- 2. Create po_line_items table (V2 summary lines)
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS po_line_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    po_id UUID REFERENCES purchase_orders(id) ON DELETE CASCADE NOT NULL,
    description TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2),
    notes TEXT,
    line_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on po_line_items
ALTER TABLE po_line_items ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to manage po_line_items for their brand
CREATE POLICY "Users can manage po_line_items for their brand" ON po_line_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM purchase_orders po
            JOIN user_profiles up ON up.brand_id = po.brand_id
            WHERE po.id = po_line_items.po_id
            AND up.id = auth.uid()
        )
    );

-- ----------------------------------------
-- 3. Indexes for performance
-- ----------------------------------------
CREATE INDEX IF NOT EXISTS idx_purchase_orders_club_id ON purchase_orders(club_id);
CREATE INDEX IF NOT EXISTS idx_po_line_items_po_id ON po_line_items(po_id);
