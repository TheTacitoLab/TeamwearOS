-- Add pattern_code column to products table
ALTER TABLE products
    ADD COLUMN IF NOT EXISTS pattern_code TEXT;
