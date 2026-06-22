-- Migration 062: Factory email recipients
-- Brand-level comma-separated list of factory email addresses, used to
-- pre-fill the "Email factory" mailto draft on each purchase order.

ALTER TABLE brands ADD COLUMN IF NOT EXISTS factory_emails text;  -- comma-separated
