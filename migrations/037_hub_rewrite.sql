-- =============================================
-- Migration 037: Order Hub Rewrite
-- Removes design approval tables and refocuses the hub
-- on player personalisation / embellishment collection.
-- TeamwearOS
-- =============================================

-- ──────────────────────────────────────────
-- Clean up approval-flow tables (no longer needed)
-- ──────────────────────────────────────────

DROP TABLE IF EXISTS kit_file_reviews;
DROP TABLE IF EXISTS kit_stage_files;

-- ──────────────────────────────────────────
-- kit_orders: remove stage unlock flags, add PIN + completion
-- ──────────────────────────────────────────

ALTER TABLE kit_orders
    DROP COLUMN IF EXISTS stage_1_unlocked,
    DROP COLUMN IF EXISTS stage_2_unlocked,
    DROP COLUMN IF EXISTS stage_3_unlocked,
    ADD COLUMN IF NOT EXISTS manager_pin_hash TEXT,
    ADD COLUMN IF NOT EXISTS completed_at     TIMESTAMPTZ;

-- ──────────────────────────────────────────
-- kit_player_details: add player token (for individual player links)
-- and lock flag (manager can lock a completed row)
-- ──────────────────────────────────────────

ALTER TABLE kit_player_details
    ADD COLUMN IF NOT EXISTS player_token TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS is_locked    BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_kit_player_details_player_token
    ON kit_player_details(player_token);
