-- Migration 061: PO receipt confirmation + issue flag
-- Brand-side "Completed" milestone (goods received at HQ) and issue beacon.

ALTER TABLE factory_purchase_orders
  ADD COLUMN IF NOT EXISTS received      boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS received_date date,
  ADD COLUMN IF NOT EXISTS issue_raised  boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS issue_note    text;
