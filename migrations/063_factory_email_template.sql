-- Migration 063: Editable factory email template
-- Brand-level subject + body templates for the "Email factory" PO draft.
-- Supports placeholders that auto-fill from the PO:
--   {po_number} {title} {club_team} {order_date} {delivery_date}
--   {drive_assets} {pps_link} {brand_name}

ALTER TABLE brands ADD COLUMN IF NOT EXISTS po_email_subject text;
ALTER TABLE brands ADD COLUMN IF NOT EXISTS po_email_body    text;
