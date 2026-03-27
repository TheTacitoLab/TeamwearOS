-- Migration 026: Design Task Record Redesign (Concepts Stage)
-- Adds concept-level approval tracking to design_stages
-- Adds is_archived flag to stage_uploads for archiving concept images

-- Add concept_statuses JSONB to design_stages
-- Stores per-concept approval state and feedback, e.g.:
-- { "concept_1": "approved", "concept_2": "declined", "concept_1_feedback": "..." }
ALTER TABLE design_stages
    ADD COLUMN IF NOT EXISTS concept_statuses JSONB DEFAULT '{}';

-- Add is_archived boolean to stage_uploads
-- Allows hiding uploaded images without deleting them
ALTER TABLE stage_uploads
    ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;

-- Index for faster filtering of non-archived uploads
CREATE INDEX IF NOT EXISTS idx_stage_uploads_not_archived
    ON stage_uploads (stage_id, is_archived);
