-- ============================================================
-- TeamwearOS Schema Extensions
-- Run these in your Supabase SQL Editor
-- ============================================================

-- ----------------------------------------
-- 1. Extend clubs table
-- ----------------------------------------
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS sport TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS is_partner BOOLEAN DEFAULT FALSE;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS contact_email TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS shopify_collection_id TEXT;

-- Auto-generate slug from name if not set
UPDATE clubs SET slug = lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))
WHERE slug IS NULL;

-- ----------------------------------------
-- 2. Extend brands table (Shopify config)
-- ----------------------------------------
ALTER TABLE brands ADD COLUMN IF NOT EXISTS shopify_domain TEXT;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS shopify_access_token TEXT;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS shopify_api_version TEXT DEFAULT '2024-01';

-- ----------------------------------------
-- 3. Create club_products table
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS club_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE NOT NULL,
    custom_name TEXT NOT NULL,
    image_url TEXT,
    web_price DECIMAL(10,2),
    partner_price DECIMAL(10,2),
    non_partner_price DECIMAL(10,2),
    shopify_product_id TEXT,
    shopify_variant_ids JSONB DEFAULT '[]',
    shopify_synced_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(club_id, product_id)
);

-- Enable RLS on club_products
ALTER TABLE club_products ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to manage club_products for their brand
CREATE POLICY "Users can manage club_products for their brand" ON club_products
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM clubs c
            JOIN user_profiles up ON up.brand_id = c.brand_id
            WHERE c.id = club_products.club_id
            AND up.id = auth.uid()
        )
    );

-- ----------------------------------------
-- 4. Create order_forms table
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS order_forms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE NOT NULL,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(24), 'hex'),
    season TEXT,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE order_forms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage order_forms for their brand" ON order_forms
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles up
            WHERE up.brand_id = order_forms.brand_id
            AND up.id = auth.uid()
        )
    );

-- Allow public read access for active forms (via token lookup)
CREATE POLICY "Public can read active order forms by token" ON order_forms
    FOR SELECT USING (is_active = TRUE);

-- ----------------------------------------
-- 5. Create order_submissions table
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS order_submissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    form_id UUID REFERENCES order_forms(id) ON DELETE CASCADE NOT NULL,
    contact_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    team_name TEXT,
    season TEXT,
    notes TEXT,
    shopify_draft_order_id TEXT,
    shopify_draft_order_status TEXT,
    shopify_draft_order_url TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES auth.users(id)
);

ALTER TABLE order_submissions ENABLE ROW LEVEL SECURITY;

-- Allow public insert (customers submitting forms)
CREATE POLICY "Public can insert submissions" ON order_submissions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM order_forms f
            WHERE f.id = order_submissions.form_id
            AND f.is_active = TRUE
        )
    );

-- Allow authenticated users to read/update submissions for their brand
CREATE POLICY "Users can read submissions for their brand" ON order_submissions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM order_forms f
            JOIN user_profiles up ON up.brand_id = f.brand_id
            WHERE f.id = order_submissions.form_id
            AND up.id = auth.uid()
        )
    );

CREATE POLICY "Users can update submissions for their brand" ON order_submissions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM order_forms f
            JOIN user_profiles up ON up.brand_id = f.brand_id
            WHERE f.id = order_submissions.form_id
            AND up.id = auth.uid()
        )
    );

-- ----------------------------------------
-- 6. Create order_submission_items table
-- ----------------------------------------
CREATE TABLE IF NOT EXISTS order_submission_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submission_id UUID REFERENCES order_submissions(id) ON DELETE CASCADE NOT NULL,
    club_product_id UUID REFERENCES club_products(id) NOT NULL,
    size TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    player_name TEXT,
    player_number TEXT,
    notes TEXT,
    line_order INTEGER DEFAULT 0
);

ALTER TABLE order_submission_items ENABLE ROW LEVEL SECURITY;

-- Allow public insert
CREATE POLICY "Public can insert submission items" ON order_submission_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM order_submissions s
            JOIN order_forms f ON f.id = s.form_id
            WHERE s.id = order_submission_items.submission_id
            AND f.is_active = TRUE
        )
    );

-- Allow authenticated users to read items for their brand
CREATE POLICY "Users can read submission items for their brand" ON order_submission_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM order_submissions s
            JOIN order_forms f ON f.id = s.form_id
            JOIN user_profiles up ON up.brand_id = f.brand_id
            WHERE s.id = order_submission_items.submission_id
            AND up.id = auth.uid()
        )
    );

-- ----------------------------------------
-- 7. Indexes for performance
-- ----------------------------------------
CREATE INDEX IF NOT EXISTS idx_club_products_club_id ON club_products(club_id);
CREATE INDEX IF NOT EXISTS idx_order_forms_club_id ON order_forms(club_id);
CREATE INDEX IF NOT EXISTS idx_order_forms_token ON order_forms(token);
CREATE INDEX IF NOT EXISTS idx_order_submissions_form_id ON order_submissions(form_id);
CREATE INDEX IF NOT EXISTS idx_order_submission_items_submission_id ON order_submission_items(submission_id);
