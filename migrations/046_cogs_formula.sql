-- COGS formula settings at brand level
ALTER TABLE brands ADD COLUMN IF NOT EXISTS cogs_payment_fee numeric(10,2) DEFAULT 0;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS cogs_formula_default_on boolean DEFAULT false;

-- Per-product COGS formula fields
ALTER TABLE products ADD COLUMN IF NOT EXISTS unit_cost numeric(10,2);
ALTER TABLE products ADD COLUMN IF NOT EXISTS cogs_formula_enabled boolean;
