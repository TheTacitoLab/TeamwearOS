-- Migration 035: Club Record Upgrades
-- Adds about, plan_content columns to clubs; creates club_contacts and club_plan_entries tables

-- 1. New text columns on clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS about TEXT;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS plan_content TEXT;

-- 2. Club contacts table
CREATE TABLE IF NOT EXISTS club_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    role TEXT,
    contact_type TEXT CHECK (contact_type IN ('manager','coach','commercial','social','partnerships','chairman')),
    is_billing_contact BOOLEAN DEFAULT FALSE,
    is_primary_contact BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE club_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "brand_scoped" ON club_contacts;
CREATE POLICY "brand_scoped" ON club_contacts
    USING (brand_id = (SELECT brand_id FROM user_profiles WHERE id = auth.uid()))
    WITH CHECK (brand_id = (SELECT brand_id FROM user_profiles WHERE id = auth.uid()));

CREATE INDEX IF NOT EXISTS idx_club_contacts_club_id ON club_contacts(club_id);
CREATE INDEX IF NOT EXISTS idx_club_contacts_brand_id ON club_contacts(brand_id);

-- 3. Club plan journal entries table
CREATE TABLE IF NOT EXISTS club_plan_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    brand_id UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
    entry_type TEXT NOT NULL CHECK (entry_type IN ('update','event','warning','meeting')),
    content TEXT NOT NULL,
    event_date DATE,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE club_plan_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "brand_scoped" ON club_plan_entries;
CREATE POLICY "brand_scoped" ON club_plan_entries
    USING (brand_id = (SELECT brand_id FROM user_profiles WHERE id = auth.uid()))
    WITH CHECK (brand_id = (SELECT brand_id FROM user_profiles WHERE id = auth.uid()));

CREATE INDEX IF NOT EXISTS idx_club_plan_entries_club_id ON club_plan_entries(club_id);
CREATE INDEX IF NOT EXISTS idx_club_plan_entries_brand_id ON club_plan_entries(brand_id);
