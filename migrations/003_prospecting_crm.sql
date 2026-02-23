-- =============================================
-- Migration 003: Prospecting CRM + Feature Toggles
-- TeamwearOS
-- =============================================

-- Feature toggles per brand (admin can enable/disable modules)
CREATE TABLE IF NOT EXISTS feature_toggles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    feature TEXT NOT NULL,  -- 'prospecting', 'sales', 'clubs', 'production', 'design_studio', 'store_generator'
    enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, feature)
);

ALTER TABLE feature_toggles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_feature_toggles" ON feature_toggles
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));
CREATE POLICY "brand_write_feature_toggles" ON feature_toggles
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));

-- Kanban stages (customizable per brand, max 3)
CREATE TABLE IF NOT EXISTS kanban_stages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#14b8a6',
    position INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE kanban_stages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_kanban_stages" ON kanban_stages
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));
CREATE POLICY "brand_write_kanban_stages" ON kanban_stages
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));

-- Insert default kanban stages (will be populated per brand on first use)
-- Default stages: 'Initial Contact', 'Proposal Sent', 'Decision Pending'

-- Leads table (covers not_contacted, in_discussion, archived)
CREATE TABLE IF NOT EXISTS leads (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,
    lead_name TEXT NOT NULL,           -- Customisable lead name
    club_name TEXT NOT NULL,           -- Mandatory
    sport TEXT,
    sport_level TEXT,                  -- e.g. 'grassroots', 'semi-pro', 'professional'
    county TEXT,
    location TEXT,
    amount_of_teams INTEGER,
    notes TEXT,
    status TEXT DEFAULT 'not_contacted' CHECK (status IN ('not_contacted', 'in_discussion', 'archived')),
    archived_reason TEXT,              -- e.g. 'not_interested'
    kanban_stage_id UUID REFERENCES kanban_stages(id) ON DELETE SET NULL,
    kanban_order INTEGER DEFAULT 0,    -- Order within Kanban column
    assigned_to UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_leads" ON leads
    USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));
CREATE POLICY "brand_write_leads" ON leads
    FOR ALL USING (brand_id IN (
        SELECT brand_id FROM user_profiles WHERE id = auth.uid()
        UNION
        SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
    ));

-- Lead contacts (basic contact details linked to a lead)
CREATE TABLE IF NOT EXISTS lead_contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    role TEXT,                         -- e.g. 'Manager', 'Secretary', 'Chairman'
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE lead_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "brand_access_lead_contacts" ON lead_contacts
    USING (lead_id IN (
        SELECT id FROM leads WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));
CREATE POLICY "brand_write_lead_contacts" ON lead_contacts
    FOR ALL USING (lead_id IN (
        SELECT id FROM leads WHERE brand_id IN (
            SELECT brand_id FROM user_profiles WHERE id = auth.uid()
            UNION
            SELECT id FROM brands WHERE EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        )
    ));

-- Indexes for performance
CREATE INDEX IF NOT EXISTS leads_brand_id_idx ON leads(brand_id);
CREATE INDEX IF NOT EXISTS leads_status_idx ON leads(status);
CREATE INDEX IF NOT EXISTS leads_kanban_stage_idx ON leads(kanban_stage_id);
CREATE INDEX IF NOT EXISTS kanban_stages_brand_id_idx ON kanban_stages(brand_id);
CREATE INDEX IF NOT EXISTS feature_toggles_brand_id_idx ON feature_toggles(brand_id);

-- Updated_at trigger for leads
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_leads_updated_at
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
