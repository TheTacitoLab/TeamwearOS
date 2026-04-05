-- =============================================
-- Migration 032: Kanban Stage Enhancements, Design Brief Questions, Asset Categories
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Design Brief Extra Questions
-- Six new open text fields on design_tasks
-- ──────────────────────────────────────────

ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS brief_team_crests           TEXT,
    ADD COLUMN IF NOT EXISTS brief_brand_logos           TEXT,
    ADD COLUMN IF NOT EXISTS brief_sponsor_logo_type     TEXT,
    ADD COLUMN IF NOT EXISTS brief_player_embellishments TEXT,
    ADD COLUMN IF NOT EXISTS brief_colour_application    TEXT,
    ADD COLUMN IF NOT EXISTS brief_piping                TEXT;

-- ──────────────────────────────────────────
-- Asset Category
-- Allows assets to be organised into sections:
--   club_logos | sponsor_logos | kit_inspiration
-- ──────────────────────────────────────────

ALTER TABLE design_task_assets
    ADD COLUMN IF NOT EXISTS asset_category TEXT;

-- ──────────────────────────────────────────
-- Factory Requirements
-- JSONB checklist stored on the design task.
-- Keys: web_images, tech_packs, pattern_artwork,
--       logo_files, logo_files_sponsor,
--       logo_files_team_crest, font_files
-- ──────────────────────────────────────────

ALTER TABLE design_tasks
    ADD COLUMN IF NOT EXISTS factory_requirements JSONB DEFAULT '{}'::jsonb;
