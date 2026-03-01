-- =============================================
-- Migration 016: Missing Columns & Hardening
-- TeamwearOS
-- =============================================
-- Adds columns that are referenced in the application
-- but were not included in prior migrations.
-- Safe to run multiple times (IF NOT EXISTS / idempotent).
-- =============================================

-- ──────────────────────────────────────────
-- clubs: Google Drive folder URL
-- Referenced in saveClubEnhanced() and rendered in the club
-- overview info panel. Absent from migrations 001-015.
-- ──────────────────────────────────────────
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS google_drive_url TEXT;
