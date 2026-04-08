-- Migration 040: Add submitter_name to kit_player_details
-- Captures the real full name of the person submitting their kit details,
-- separate from player_name which is the jersey imprint name (e.g. BECKHAM).

ALTER TABLE kit_player_details
    ADD COLUMN IF NOT EXISTS submitter_name TEXT;
