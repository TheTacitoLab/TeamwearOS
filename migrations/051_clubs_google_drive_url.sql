-- Migration 051: Add Google Drive URL to clubs
-- Used as a fallback Factory Drive Folder source for design tasks linked to
-- the club but without a job-level Drive URL set.

ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS google_drive_url TEXT;
