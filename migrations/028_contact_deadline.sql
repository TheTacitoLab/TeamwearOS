-- Migration 028: Add contact record fields and deadline date to jobs
-- Contact details: a simple point-of-contact for the job (name, role, email, phone)
-- Deadline date: event/match day; order_target_date is calculated (deadline - 7 weeks) in JS

ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS contact_name  TEXT,
  ADD COLUMN IF NOT EXISTS contact_role  TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS deadline_date DATE;
