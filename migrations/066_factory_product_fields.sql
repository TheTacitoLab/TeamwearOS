-- Add factory-specific fields to products for the Factory Master Product list
ALTER TABLE products ADD COLUMN IF NOT EXISTS factory_unit_cost DECIMAL(10,2);
ALTER TABLE products ADD COLUMN IF NOT EXISTS factory_notes TEXT;
