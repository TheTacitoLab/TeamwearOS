-- Migration 058: Explicit per-recipe fabric weight for size Large garment
-- Replaces the inaccurate (total_fabric_kg × allocation_pct) calculation with
-- a direct weight entered per recipe component, tied to the specific fabric's GSM.
-- NULL rows fall through to the legacy calculation for backward compatibility.

ALTER TABLE product_fabric_recipes
    ADD COLUMN IF NOT EXISTS weight_size_l_kg numeric(8,4);
