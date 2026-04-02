-- Migration 029: Add Google Drive URL to jobs table
-- Used as the Factory Order Folder link, displayed in the job record overview
-- and pulled into Design Task Record stage 5 (Upload To Drive).

ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS google_drive_url TEXT;
