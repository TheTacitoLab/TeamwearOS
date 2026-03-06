-- Migration 021: Design Studio — version comments & storage bucket
-- Adds upload_id to stage_status_log so comments can be tied to a specific
-- version upload (not just a stage), enabling per-version comment threads.

-- Add upload_id column (nullable — only set for per-version comments)
ALTER TABLE stage_status_log
    ADD COLUMN IF NOT EXISTS upload_id uuid REFERENCES stage_uploads(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_stage_status_log_upload ON stage_status_log(upload_id);

-- Ensure the design-uploads storage bucket exists.
-- This is handled programmatically in the app via supabase.storage.createBucket()
-- but the bucket can also be created from the Supabase dashboard:
--   Name: design-uploads  |  Public: true  |  File size limit: 50MB
