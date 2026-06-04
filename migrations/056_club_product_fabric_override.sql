-- Migration 056: Add per-component fabric override to club product colour selections
-- Allows club products to choose a specific fabric per recipe component
-- (pre-populated from master recipe, overridable with any active fabric)

ALTER TABLE club_product_colour_selections
    ADD COLUMN IF NOT EXISTS fabric_id uuid REFERENCES fabrics(id);
